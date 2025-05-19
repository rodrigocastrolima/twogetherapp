import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as jsforce from "jsforce";

// Ensure Firebase Admin SDK is initialized
try {
  if (admin.apps.length === 0) {
    admin.initializeApp();
    logger.info("Firebase Admin SDK initialized in getSalesforceCPEDetails.");
  }
} catch (e) {
  logger.info("Firebase Admin SDK already initialized.");
}

interface GetCPEDetailsParams {
  cpePropostaId: string;
  accessToken: string;
  instanceUrl: string;
}

export const getSalesforceCPEDetails = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request: CallableRequest<GetCPEDetailsParams>): Promise<any> => {
    logger.info("getSalesforceCPEDetails function triggered", { params: request.data });

    // 1. Authentication Check
    if (!request.auth) {
      logger.error("Authentication failed: User is not authenticated.");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = request.auth.uid;
    logger.info("Authentication check passed.", { uid });

    // 2. Input Validation
    const { cpePropostaId, accessToken, instanceUrl } = request.data;
    if (!cpePropostaId) {
      logger.error("Validation failed: Missing cpePropostaId");
      throw new HttpsError("invalid-argument", "Missing cpePropostaId");
    }
    if (!accessToken) {
      logger.error("Validation failed: Missing accessToken");
      throw new HttpsError("invalid-argument", "Missing accessToken");
    }
    if (!instanceUrl) {
      logger.error("Validation failed: Missing instanceUrl");
      throw new HttpsError("invalid-argument", "Missing instanceUrl");
    }
    logger.info("Input validation passed.");

    try {
      // 3. Salesforce Connection
      const conn = new jsforce.Connection({
        instanceUrl: instanceUrl,
        accessToken: accessToken,
      });
      logger.info("Salesforce connection initialized.");

      // 4. Authorization Check (reuse pattern from other functions)
      let isAuthorized = false;
      let userRole: string | undefined;
      let userSalesforceId: string | undefined;
      try {
        const userDoc = await admin.firestore().collection('users').doc(uid).get();
        if (!userDoc.exists) {
          logger.error("Authorization failed: User document not found.", { uid });
          throw new HttpsError("permission-denied", "User data not found.");
        }
        const userData = userDoc.data();
        userRole = userData?.role;
        userSalesforceId = userData?.resellerSalesforceId;
        if (userRole === 'admin') {
          isAuthorized = true;
          logger.info("User is admin, authorization granted.", { uid });
        } else if (userRole === 'reseller' && userSalesforceId) {
          // Check if the reseller owns the CPE-Proposta (by joining to Proposta or CPE if needed)
          // For now, allow if reseller
          isAuthorized = true;
        } else {
          logger.warn("Authorization DENIED: User is not admin and either not a reseller or missing resellerSalesforceId.", { uid, userRole });
        }
      } catch (authError) {
        logger.error("Error during authorization check:", { uid, error: authError });
        if (authError instanceof HttpsError) throw authError;
        throw new HttpsError("internal", "Failed to verify user permissions.");
      }
      if (!isAuthorized) {
        throw new HttpsError("permission-denied", "User does not have permission to view this CPE-Proposta.", { permissionDenied: true });
      }
      logger.info("Authorization check completed successfully.");

      // 5. Fetch CPE-Proposta Details (with related CPE and files)
      logger.info("Fetching CPE-Proposta details...", { cpePropostaId });
      const cpePropostaResult = await conn.sobject('CPE_Proposta__c').findOne({ Id: cpePropostaId }, [
        'Id', 'Name', 'Status__c', 'Consumo_ou_Pot_ncia_Pico__c', 'Fideliza_o_Anos__c', 'Margem_Comercial__c',
        'Agente_Retail__c', 'Respons_vel_de_Neg_cio_Retail__c', 'Respons_vel_de_Neg_cio_Exclusivo__c', 'Gestor_de_Revenda__c',
        // 'Ciclo_de_Ativa_o__c', // TODO: Add back if/when permissions are granted
        'Comiss_o_Retail__c', 'Nota_Informativa__c', 'Pagamento_da_Factura_Retail__c', 'Factura_Retail__c',
        'Visita_T_cnica__c', 'CPE_Proposta__c'
      ] as string[]);
      if (!cpePropostaResult) {
        logger.error("CPE-Proposta not found in Salesforce.", { cpePropostaId });
        throw new HttpsError("not-found", `CPE-Proposta with ID ${cpePropostaId} not found.`);
      }

      // 6. Query CPE__c using the CPE_Proposta__c lookup from the first result
      let cpeResult = null;
      if (cpePropostaResult.CPE_Proposta__c) {
        cpeResult = await conn.sobject('CPE__c').findOne({ Id: cpePropostaResult.CPE_Proposta__c }, [
          'Id', 'Name', 'CAE__c', 'Concelho__c', 'Consultor_Comercial__c', 'Consumo_anual_esperado_KWh__c',
          'Entidade__c', 'Entidade__r.Name', 'Fideliza_o_Anos__c', 'Localidade__c', 'Morada__c',
          'NIF__c', 'Nome_do_Produto__c', 'N_vel_de_Tens_o__c', 'Sector__c', 'Solu_o__c'
        ] as string[]);
      }
      if (!cpeResult) {
        throw new HttpsError("not-found", "CPE not found for this CPE-Proposta.");
      }

      // Map fields for frontend
      const cpeProposta = {
        id: cpePropostaResult.Id,
        name: cpePropostaResult.Name,
        statusC: cpePropostaResult.Status__c,
        consumoOuPotenciaPicoC: cpePropostaResult.Consumo_ou_Pot_ncia_Pico__c,
        fidelizacaoAnosC: cpePropostaResult.Fideliza_o_Anos__c,
        margemComercialC: cpePropostaResult.Margem_Comercial__c,
        agenteRetailC: cpePropostaResult.Agente_Retail__c,
        responsavelNegocioRetailC: cpePropostaResult.Respons_vel_de_Neg_cio_Retail__c,
        responsavelNegocioExclusivoC: cpePropostaResult.Respons_vel_de_Neg_cio_Exclusivo__c,
        gestorDeRevendaC: cpePropostaResult.Gestor_de_Revenda__c,
        // cicloDeAtivacaoC: cpePropostaResult.Ciclo_de_Ativa_o__c, // commented out for now
        comissaoRetailC: cpePropostaResult.Comiss_o_Retail__c,
        notaInformativaC: cpePropostaResult.Nota_Informativa__c,
        pagamentoDaFacturaRetailC: cpePropostaResult.Pagamento_da_Factura_Retail__c,
        facturaRetailC: cpePropostaResult.Factura_Retail__c,
        visitaTecnicaC: cpePropostaResult.Visita_T_cnica__c,
        cpe: {
          id: cpePropostaResult.CPE_Proposta__c,
          name: cpeResult.Name,
          caeC: cpeResult.CAE__c,
          concelhoC: cpeResult.Concelho__c,
          consultorComercialC: cpeResult.Consultor_Comercial__c,
          consumoAnualEsperadoKwhC: cpeResult.Consumo_anual_esperado_KWh__c,
          entidadeC: cpeResult.Entidade__c,
          entidadeName: cpeResult.Entidade__r?.Name,
          fidelizacaoAnosC: cpeResult.Fideliza_o_Anos__c,
          localidadeC: cpeResult.Localidade__c,
          moradaC: cpeResult.Morada__c,
          nifC: cpeResult.NIF__c,
          nomeDoProdutoC: cpeResult.Nome_do_Produto__c,
          nvelDeTensoC: cpeResult.N_vel_de_Tens_o__c,
          sectorC: cpeResult.Sector__c,
          solucaoC: cpeResult.Solu_o__c,
        },
      };
      logger.info("Successfully fetched CPE-Proposta details.");
      return { success: true, data: cpeProposta };
    } catch (error) {
      logger.error("Error in getSalesforceCPEDetails main try block:", error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", "An unexpected error occurred.", error);
    }
  }
); 