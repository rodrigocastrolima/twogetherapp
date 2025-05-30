# TwogetherApp - Comprehensive Pseudo Code

## 1. Main Application Entry Point

```pseudocode
FUNCTION main():
    // Initialize Flutter app
    CALL WidgetsFlutterBinding.ensureInitialized()
    CALL setPathUrlStrategy() // For web URL handling
    
    // Initialize Firebase
    AWAIT Firebase.initializeApp()
    IF platform == WEB:
        AWAIT FirebaseAuth.setPersistence(LOCAL)
    
    // Initialize SharedPreferences
    sharedPreferences = AWAIT SharedPreferences.getInstance()
    
    // Create Provider Container with overrides
    container = CREATE ProviderContainer WITH sharedPreferences override
    
    // Handle Salesforce callback on web
    IF platform == WEB:
        AWAIT handleSalesforceWebCallback(container)
    
    // Initialize Salesforce auth state
    READ salesforceAuthProvider FROM container
    
    // Register Firebase Messaging background handler
    REGISTER firebaseMessagingBackgroundHandler
    
    // Initialize FilePicker
    TRY:
        AWAIT FilePicker.clearTemporaryFiles()
    CATCH error:
        LOG "FilePicker initialization error: " + error
    
    // Check Cloud Functions availability
    functionsService = CREATE FirebaseFunctionsService()
    cloudFunctionsAvailable = AWAIT functionsService.checkAvailability()
    
    // Run the app
    RUN TwogetherApp WITH container
END FUNCTION

FUNCTION TwogetherApp():
    // Listen for auth state changes
    LISTEN_TO FirebaseAuth.authStateChanges():
        ON user_change:
            IF user != null AND platform == WEB AND !initialAuthCheckDone:
                CALL checkSalesforceCallbackAndNavigate()
    
    // Build app with theme and router
    RETURN MaterialApp.router WITH:
        theme = AppTheme.lightTheme
        darkTheme = AppTheme.darkTheme
        routerConfig = AppRouter.router
END FUNCTION
```

## 2. Authentication System

```pseudocode
CLASS AuthNotifier:
    PROPERTIES:
        isAuthenticated = false
        isAdmin = false
        isFirstLogin = false
        initialPasswordChanged = false
        salesforceId = null
    
    FUNCTION initAuth():
        LISTEN_TO FirebaseAuth.authStateChanges():
            ON user_change(user):
                IF user != null:
                    TRY:
                        // Get user data from Firestore
                        doc = AWAIT Firestore.collection('users').doc(user.uid).get()
                        IF doc.exists:
                            data = doc.data()
                            role = data['role']
                            isFirstLogin = data['isFirstLogin'] ?? false
                            initialPasswordChanged = data['initialPasswordChanged'] ?? true
                            salesforceId = data['salesforceId']
                            
                            SET isAuthenticated = true
                            SET isAdmin = (role.toLowerCase() == 'admin')
                            SET this.isFirstLogin = isFirstLogin
                            SET this.initialPasswordChanged = initialPasswordChanged
                            SET this.salesforceId = salesforceId
                            
                            // Update FCM token
                            AWAIT updateFcmToken()
                            
                            LISTEN_TO FirebaseMessaging.onTokenRefresh:
                                ON token_refresh(newToken):
                                    AWAIT updateFcmToken(newToken)
                        ELSE:
                            // No user data in Firestore
                            SET isAuthenticated = true
                            SET isAdmin = false
                            SET isFirstLogin = true
                            SET initialPasswordChanged = false
                    CATCH error:
                        LOG "Error fetching user data: " + error
                        RESET all auth properties
                ELSE:
                    // User signed out
                    AWAIT removeFcmToken()
                    RESET all auth properties
                
                NOTIFY listeners
    END FUNCTION
    
    FUNCTION updateFcmToken(token = null):
        user = FirebaseAuth.currentUser
        IF user == null: RETURN
        
        IF token == null:
            token = AWAIT FirebaseMessaging.getToken()
        
        IF token != null:
            AWAIT Firestore.collection('users').doc(user.uid).update({
                'fcmToken': token,
                'lastTokenUpdate': FieldValue.serverTimestamp()
            })
    END FUNCTION
END CLASS
```

## 3. Router and Navigation

```pseudocode
CLASS AppRouter:
    FUNCTION redirect(context, state):
        // Get current auth state
        isAuthenticated = authNotifier.isAuthenticated
        isAdmin = authNotifier.isAdmin
        currentRoute = state.matchedLocation
        
        // Check authentication
        IF !isAuthenticated AND currentRoute != '/login' AND currentRoute != '/auth-loading':
            RETURN '/login'
        
        // Handle authenticated users
        IF isAuthenticated:
            // Check password change requirement
            IF !authNotifier.initialPasswordChanged AND currentRoute != '/change-password':
                RETURN '/change-password'
            
            // Role-based routing
            IF isAdmin:
                allowedNonAdminPaths = ['/proposal/create', '/review-this-submission']
                IF !currentRoute.startsWith('/admin') AND currentRoute NOT IN allowedNonAdminPaths:
                    RETURN '/admin'
                
                // Check Salesforce connection for admin
                salesforceState = GET salesforceAuthProvider FROM context
                IF salesforceState.needsConnection AND currentRoute != '/admin/salesforce-connect':
                    RETURN '/admin/salesforce-connect'
            ELSE:
                // Reseller restrictions
                IF currentRoute.startsWith('/admin') OR currentRoute == '/proposal/create':
                    RETURN '/'
        
        RETURN null // Allow navigation
    END FUNCTION
    
    FUNCTION routes():
        RETURN [
            // Authentication routes
            GoRoute('/login', LoginPage),
            GoRoute('/change-password', ChangePasswordPage),
            GoRoute('/auth-loading', AuthLoadingPage),
            
            // Reseller shell routes
            ShellRoute(MainLayout, [
                GoRoute('/', ResellerHomePage),
                GoRoute('/clients', ClientsPage),
                GoRoute('/messages', MessagesPage),
                GoRoute('/settings', SettingsPage)
            ]),
            
            // Admin shell routes
            ShellRoute(AdminLayout, [
                GoRoute('/admin', AdminHomePage),
                GoRoute('/admin/opportunities', OpportunityVerificationPage),
                GoRoute('/admin/user-management', UserManagementPage),
                GoRoute('/admin/messages', AdminChatPage),
                GoRoute('/admin/settings', AdminSettingsPage)
            ]),
            
            // Detailed routes
            GoRoute('/admin/opportunity-detail', OpportunityDetailsPage),
            GoRoute('/proposal/create', ProposalCreationPage),
            GoRoute('/profile-details', ProfilePage),
            // ... more routes
        ]
    END FUNCTION
END CLASS
```

## 4. Admin Features

```pseudocode
CLASS UserManagementController:
    FUNCTION createUser(userData):
        TRY:
            // Validate user data
            VALIDATE userData.email, userData.salesforceId, userData.role
            
            // Check if Salesforce ID exists
            existsResult = AWAIT CloudFunctions.call('checkNifExistsInSalesforce', {
                nif: userData.salesforceId
            })
            
            IF !existsResult.exists:
                THROW "Salesforce ID not found"
            
            // Create Firebase user
            createResult = AWAIT CloudFunctions.call('createUser', {
                email: userData.email,
                salesforceId: userData.salesforceId,
                role: userData.role,
                name: userData.name
            })
            
            IF createResult.success:
                // Sync with Salesforce
                AWAIT syncUserWithSalesforce(createResult.userId, userData.salesforceId)
                
                // Send notification
                AWAIT sendUserCreationNotification(userData.email)
                
                RETURN SUCCESS
            ELSE:
                THROW createResult.error
        CATCH error:
            LOG "Error creating user: " + error
            THROW error
    END FUNCTION
    
    FUNCTION syncUserWithSalesforce(userId, salesforceId):
        TRY:
            // Get Salesforce user data
            salesforceData = AWAIT SalesforceService.getUser(salesforceId)
            
            // Update Firestore with Salesforce data
            AWAIT Firestore.collection('users').doc(userId).update({
                'salesforceData': salesforceData,
                'lastSalesforceSync': FieldValue.serverTimestamp()
            })
        CATCH error:
            LOG "Error syncing with Salesforce: " + error
    END FUNCTION
END CLASS

CLASS OpportunityManagementController:
    FUNCTION createOpportunity(opportunityData):
        TRY:
            // Validate opportunity data
            VALIDATE opportunityData
            
            // Create in Salesforce via Cloud Function
            result = AWAIT CloudFunctions.call('createSalesforceOpportunity', {
                name: opportunityData.name,
                accountId: opportunityData.accountId,
                resellerId: opportunityData.resellerId,
                amount: opportunityData.amount,
                closeDate: opportunityData.closeDate,
                stage: opportunityData.stage
            })
            
            IF result.success:
                // Update local cache
                AWAIT updateLocalOpportunityCache(result.opportunityId, result.opportunityData)
                
                // Notify assigned reseller
                AWAIT notifyResellerOfNewOpportunity(opportunityData.resellerId, result.opportunityId)
                
                RETURN result.opportunityId
            ELSE:
                THROW result.error
        CATCH error:
            LOG "Error creating opportunity: " + error
            THROW error
    END FUNCTION
    
    FUNCTION reviewServiceSubmission(submissionId, decision, comments):
        TRY:
            submission = AWAIT Firestore.collection('service_submissions').doc(submissionId).get()
            
            IF decision == 'APPROVED':
                // Create opportunity from submission
                opportunityId = AWAIT createOpportunityFromSubmission(submission.data())
                
                // Update submission status
                AWAIT Firestore.collection('service_submissions').doc(submissionId).update({
                    'status': 'APPROVED',
                    'reviewComments': comments,
                    'reviewedAt': FieldValue.serverTimestamp(),
                    'reviewedBy': getCurrentUser().uid,
                    'opportunityId': opportunityId
                })
            ELSE:
                // Reject submission
                AWAIT Firestore.collection('service_submissions').doc(submissionId).update({
                    'status': 'REJECTED',
                    'reviewComments': comments,
                    'reviewedAt': FieldValue.serverTimestamp(),
                    'reviewedBy': getCurrentUser().uid
                })
            
            // Notify submitter
            AWAIT notifySubmissionDecision(submission.data().resellerId, decision, comments)
        CATCH error:
            LOG "Error reviewing submission: " + error
            THROW error
    END FUNCTION
END CLASS

CLASS AdminChatController:
    FUNCTION getConversations():
        RETURN Firestore.collection('conversations')
            .where('participants', 'array-contains', 'admin')
            .orderBy('lastMessageTime', 'desc')
            .snapshots()
    END FUNCTION
    
    FUNCTION sendMessage(conversationId, message):
        TRY:
            // Add message to Firestore
            messageRef = Firestore.collection('conversations').doc(conversationId)
                .collection('messages').doc()
            
            AWAIT messageRef.set({
                'id': messageRef.id,
                'senderId': getCurrentUser().uid,
                'senderName': getCurrentUser().displayName,
                'content': message.content,
                'timestamp': FieldValue.serverTimestamp(),
                'isAdmin': true,
                'isRead': false,
                'type': message.type,
                'isDefault': false
            })
            
            // Update conversation
            AWAIT Firestore.collection('conversations').doc(conversationId).update({
                'lastMessageContent': message.content,
                'lastMessageTime': FieldValue.serverTimestamp(),
                'unreadCounts.reseller': FieldValue.increment(1)
            })
            
            // Send push notification
            AWAIT CloudFunctions.call('sendChatNotification', {
                conversationId: conversationId,
                message: message.content,
                senderType: 'admin'
            })
        CATCH error:
            LOG "Error sending message: " + error
            THROW error
    END FUNCTION
END CLASS
```

## 5. Reseller Features

```pseudocode
CLASS ResellerHomeController:
    FUNCTION loadDashboardData():
        TRY:
            // Get reseller's Salesforce ID
            user = AWAIT getCurrentUserFromFirestore()
            salesforceId = user.salesforceId
            
            // Load opportunities via JWT-authenticated Cloud Function
            opportunities = AWAIT CloudFunctions.call('getResellerOpportunities', {
                resellerId: salesforceId
            })
            
            // Load recent proposals
            proposals = AWAIT CloudFunctions.call('getResellerProposalDetails', {
                resellerId: salesforceId,
                limit: 5
            })
            
            // Load revenue statistics
            stats = AWAIT CloudFunctions.call('getResellerDashboardStats', {
                resellerId: salesforceId
            })
            
            RETURN {
                opportunities: opportunities.data,
                proposals: proposals.data,
                stats: stats.data
            }
        CATCH error:
            LOG "Error loading dashboard data: " + error
            THROW error
    END FUNCTION
END CLASS

CLASS ClientsController:
    FUNCTION getOpportunities():
        user = AWAIT getCurrentUserFromFirestore()
        
        RETURN CloudFunctions.call('getResellerOpportunities', {
            resellerId: user.salesforceId
        })
    END FUNCTION
    
    FUNCTION getOpportunityDetails(opportunityId):
        RETURN CloudFunctions.call('getSalesforceOpportunityDetails', {
            opportunityId: opportunityId
        })
    END FUNCTION
    
    FUNCTION getProposals(opportunityId):
        RETURN CloudFunctions.call('getOpportunityProposals', {
            opportunityId: opportunityId
        })
    END FUNCTION
END CLASS

CLASS ProposalCreationController:
    FUNCTION createProposal(proposalData):
        TRY:
            // Upload documents to Firebase Storage
            uploadedFiles = []
            FOR EACH file IN proposalData.files:
                fileUrl = AWAIT uploadFileToFirebaseStorage(file)
                uploadedFiles.push(fileUrl)
            
            // Create proposal in Salesforce
            result = AWAIT CloudFunctions.call('createSalesforceProposal', {
                opportunityId: proposalData.opportunityId,
                accountId: proposalData.accountId,
                resellerId: proposalData.resellerId,
                proposalData: proposalData.formData,
                documentUrls: uploadedFiles
            })
            
            IF result.success:
                // Notify admin of new proposal
                AWAIT CloudFunctions.call('sendNotification', {
                    type: 'NEW_PROPOSAL',
                    proposalId: result.proposalId,
                    resellerId: proposalData.resellerId
                })
                
                RETURN result.proposalId
            ELSE:
                THROW result.error
        CATCH error:
            LOG "Error creating proposal: " + error
            THROW error
    END FUNCTION
    
    FUNCTION uploadFileToFirebaseStorage(file):
        TRY:
            fileName = generateUniqueFileName(file.name)
            storageRef = FirebaseStorage.ref().child('proposals/' + fileName)
            
            uploadTask = storageRef.putFile(file)
            
            // Monitor upload progress
            LISTEN_TO uploadTask.snapshotEvents:
                ON progress_change:
                    progress = snapshot.bytesTransferred / snapshot.totalBytes
                    UPDATE upload_progress_ui(progress)
            
            snapshot = AWAIT uploadTask
            downloadUrl = AWAIT snapshot.ref.getDownloadURL()
            
            RETURN downloadUrl
        CATCH error:
            LOG "Error uploading file: " + error
            THROW error
    END FUNCTION
END CLASS

CLASS ServiceSubmissionController:
    FUNCTION submitServiceRequest(submissionData):
        TRY:
            // Upload documents
            uploadedFiles = []
            FOR EACH file IN submissionData.files:
                fileUrl = AWAIT uploadFileToFirebaseStorage(file)
                uploadedFiles.push(fileUrl)
            
            // Create submission in Firestore
            submissionRef = Firestore.collection('service_submissions').doc()
            
            AWAIT submissionRef.set({
                'id': submissionRef.id,
                'resellerId': getCurrentUser().uid,
                'resellerName': getCurrentUser().displayName,
                'serviceType': submissionData.serviceType,
                'clientInfo': submissionData.clientInfo,
                'description': submissionData.description,
                'documents': uploadedFiles,
                'status': 'PENDING',
                'submittedAt': FieldValue.serverTimestamp()
            })
            
            // Notify admin
            AWAIT CloudFunctions.call('sendNotification', {
                type: 'NEW_SERVICE_SUBMISSION',
                submissionId: submissionRef.id,
                resellerId: getCurrentUser().uid
            })
            
            RETURN submissionRef.id
        CATCH error:
            LOG "Error submitting service request: " + error
            THROW error
    END FUNCTION
END CLASS

CLASS ResellerChatController:
    FUNCTION getConversation():
        resellerId = getCurrentUser().uid
        
        // Find or create conversation
        conversationQuery = Firestore.collection('conversations')
            .where('participants', 'array-contains', resellerId)
            .limit(1)
        
        conversations = AWAIT conversationQuery.get()
        
        IF conversations.isEmpty:
            // Create new conversation
            conversationRef = Firestore.collection('conversations').doc()
            
            AWAIT conversationRef.set({
                'id': conversationRef.id,
                'resellerId': resellerId,
                'resellerName': getCurrentUser().displayName,
                'participants': ['admin', resellerId],
                'active': false,
                'unreadCounts': {
                    'admin': 0,
                    'reseller': 0
                },
                'createdAt': FieldValue.serverTimestamp()
            })
            
            // Add welcome message
            AWAIT addWelcomeMessage(conversationRef.id)
            
            RETURN conversationRef.id
        ELSE:
            RETURN conversations.docs.first.id
    END FUNCTION
    
    FUNCTION sendMessage(conversationId, message):
        TRY:
            // Add message
            messageRef = Firestore.collection('conversations').doc(conversationId)
                .collection('messages').doc()
            
            AWAIT messageRef.set({
                'id': messageRef.id,
                'senderId': getCurrentUser().uid,
                'senderName': getCurrentUser().displayName,
                'content': message.content,
                'timestamp': FieldValue.serverTimestamp(),
                'isAdmin': false,
                'isRead': false,
                'type': message.type,
                'isDefault': false
            })
            
            // Update conversation
            AWAIT Firestore.collection('conversations').doc(conversationId).update({
                'lastMessageContent': message.content,
                'lastMessageTime': FieldValue.serverTimestamp(),
                'active': true,
                'unreadCounts.admin': FieldValue.increment(1)
            })
            
            // Send notification to admin
            AWAIT CloudFunctions.call('sendChatNotification', {
                conversationId: conversationId,
                message: message.content,
                senderType: 'reseller'
            })
        CATCH error:
            LOG "Error sending message: " + error
            THROW error
    END FUNCTION
END CLASS
```

## 6. Firebase Cloud Functions

```pseudocode
// User Management Functions
FUNCTION createUser(data):
    TRY:
        // Validate input
        email = data.email
        salesforceId = data.salesforceId
        role = data.role
        name = data.name
        
        // Generate random password
        tempPassword = generateRandomPassword()
        
        // Create Firebase user
        userRecord = AWAIT admin.auth().createUser({
            email: email,
            password: tempPassword,
            displayName: name
        })
        
        // Set custom claims
        AWAIT admin.auth().setCustomUserClaims(userRecord.uid, {
            role: role
        })
        
        // Create user document in Firestore
        AWAIT admin.firestore().collection('users').doc(userRecord.uid).set({
            email: email,
            salesforceId: salesforceId,
            role: role,
            name: name,
            isFirstLogin: true,
            initialPasswordChanged: false,
            createdAt: FieldValue.serverTimestamp()
        })
        
        // Send welcome email with temp password
        AWAIT sendWelcomeEmail(email, tempPassword)
        
        RETURN { success: true, userId: userRecord.uid }
    CATCH error:
        LOG "Error creating user: " + error
        RETURN { success: false, error: error.message }
END FUNCTION

// Salesforce Integration Functions (JWT Bearer Flow)
FUNCTION getResellerOpportunities(data):
    TRY:
        resellerId = data.resellerId
        
        // Generate JWT token for Salesforce
        accessToken = AWAIT generateSalesforceJWTToken()
        
        // Query Salesforce API
        query = "SELECT Id, Name, Account.Name, Amount, CloseDate, StageName, CreatedDate " +
                "FROM Opportunity WHERE Reseller__c = '" + resellerId + "' " +
                "ORDER BY CreatedDate DESC"
        
        response = AWAIT axios.get(SF_INSTANCE_URL + '/services/data/v58.0/query', {
            headers: {
                'Authorization': 'Bearer ' + accessToken,
                'Content-Type': 'application/json'
            },
            params: { q: query }
        })
        
        RETURN { success: true, data: response.data.records }
    CATCH error:
        LOG "Error getting reseller opportunities: " + error
        RETURN { success: false, error: error.message }
END FUNCTION

FUNCTION generateSalesforceJWTToken():
    TRY:
        // JWT payload
        payload = {
            iss: CONSUMER_KEY,
            sub: SALESFORCE_USERNAME,
            aud: 'https://login.salesforce.com',
            exp: Math.floor(Date.now() / 1000) + (5 * 60) // 5 minutes
        }
        
        // Sign JWT with private key
        token = jwt.sign(payload, PRIVATE_KEY, { algorithm: 'RS256' })
        
        // Exchange JWT for access token
        response = AWAIT axios.post('https://login.salesforce.com/services/oauth2/token', {
            grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            assertion: token
        })
        
        RETURN response.data.access_token
    CATCH error:
        LOG "Error generating JWT token: " + error
        THROW error
END FUNCTION

FUNCTION createSalesforceOpportunity(data):
    TRY:
        accessToken = AWAIT generateSalesforceJWTToken()
        
        opportunityData = {
            Name: data.name,
            AccountId: data.accountId,
            Reseller__c: data.resellerId,
            Amount: data.amount,
            CloseDate: data.closeDate,
            StageName: data.stage,
            Type: 'New Business'
        }
        
        response = AWAIT axios.post(SF_INSTANCE_URL + '/services/data/v58.0/sobjects/Opportunity', 
            opportunityData, {
                headers: {
                    'Authorization': 'Bearer ' + accessToken,
                    'Content-Type': 'application/json'
                }
            })
        
        RETURN { success: true, opportunityId: response.data.id }
    CATCH error:
        LOG "Error creating Salesforce opportunity: " + error
        RETURN { success: false, error: error.message }
END FUNCTION

FUNCTION downloadFileForReseller(data):
    TRY:
        fileId = data.fileId
        resellerId = data.resellerId
        
        // Verify reseller has access to this file
        hasAccess = AWAIT verifyResellerFileAccess(resellerId, fileId)
        IF !hasAccess:
            THROW "Access denied"
        
        accessToken = AWAIT generateSalesforceJWTToken()
        
        // Get file content from Salesforce
        response = AWAIT axios.get(SF_INSTANCE_URL + '/services/data/v58.0/sobjects/ContentVersion/' + fileId + '/VersionData', {
            headers: {
                'Authorization': 'Bearer ' + accessToken
            },
            responseType: 'arraybuffer'
        })
        
        // Return file data as base64
        fileContent = Buffer.from(response.data).toString('base64')
        
        RETURN { success: true, fileContent: fileContent, contentType: response.headers['content-type'] }
    CATCH error:
        LOG "Error downloading file: " + error
        RETURN { success: false, error: error.message }
END FUNCTION

// Notification Functions
FUNCTION sendChatNotification(data):
    TRY:
        conversationId = data.conversationId
        message = data.message
        senderType = data.senderType
        
        // Get conversation participants
        conversation = AWAIT admin.firestore().collection('conversations').doc(conversationId).get()
        participants = conversation.data().participants
        
        // Determine recipient
        recipient = senderType == 'admin' ? 'reseller' : 'admin'
        
        // Get FCM tokens for recipient
        IF recipient == 'admin':
            // Get admin users
            adminUsers = AWAIT admin.firestore().collection('users')
                .where('role', '==', 'admin').get()
            
            FOR EACH adminUser IN adminUsers.docs:
                fcmToken = adminUser.data().fcmToken
                IF fcmToken:
                    AWAIT admin.messaging().send({
                        token: fcmToken,
                        notification: {
                            title: 'New Message',
                            body: message
                        },
                        data: {
                            type: 'chat',
                            conversationId: conversationId
                        }
                    })
        ELSE:
            // Get reseller FCM token
            resellerId = conversation.data().resellerId
            resellerDoc = AWAIT admin.firestore().collection('users').doc(resellerId).get()
            fcmToken = resellerDoc.data().fcmToken
            
            IF fcmToken:
                AWAIT admin.messaging().send({
                    token: fcmToken,
                    notification: {
                        title: 'Admin Message',
                        body: message
                    },
                    data: {
                        type: 'chat',
                        conversationId: conversationId
                    }
                })
    CATCH error:
        LOG "Error sending chat notification: " + error
END FUNCTION

// Message Cleanup Function
FUNCTION messageCleanup():
    TRY:
        cutoffDate = new Date()
        cutoffDate.setDate(cutoffDate.getDate() - 30) // 30 days ago
        
        // Find old conversations
        oldConversations = AWAIT admin.firestore().collection('conversations')
            .where('lastMessageTime', '<', cutoffDate)
            .where('active', '==', false)
            .get()
        
        FOR EACH conversation IN oldConversations.docs:
            // Delete all messages in the conversation
            messages = AWAIT conversation.ref.collection('messages').get()
            
            FOR EACH message IN messages.docs:
                AWAIT message.ref.delete()
            
            // Delete the conversation
            AWAIT conversation.ref.delete()
        
        LOG "Cleaned up " + oldConversations.size + " old conversations"
    CATCH error:
        LOG "Error in message cleanup: " + error
END FUNCTION
```

## 7. Salesforce OAuth Integration (Admin)

```pseudocode
CLASS SalesforceAuthService:
    FUNCTION initiateOAuthFlow():
        TRY:
            // Generate PKCE parameters
            codeVerifier = generateCodeVerifier()
            codeChallenge = generateCodeChallenge(codeVerifier)
            state = generateRandomState()
            
            // Store verifier securely
            AWAIT SecureStorage.write('salesforce_code_verifier', codeVerifier)
            AWAIT SecureStorage.write('salesforce_state', state)
            
            // Build authorization URL
            authUrl = SALESFORCE_AUTH_URL + '?' +
                'response_type=code&' +
                'client_id=' + CLIENT_ID + '&' +
                'redirect_uri=' + REDIRECT_URI + '&' +
                'scope=api refresh_token&' +
                'code_challenge=' + codeChallenge + '&' +
                'code_challenge_method=S256&' +
                'state=' + state
            
            // Launch browser for auth
            IF platform == WEB:
                window.location.href = authUrl
            ELSE:
                result = AWAIT FlutterWebAuth2.authenticate(authUrl, REDIRECT_URI)
                AWAIT handleAuthCallback(result.url)
            
        CATCH error:
            LOG "Error initiating OAuth flow: " + error
            THROW error
    END FUNCTION
    
    FUNCTION handleAuthCallback(callbackUrl):
        TRY:
            // Parse callback URL
            uri = Uri.parse(callbackUrl)
            authCode = uri.queryParameters['code']
            state = uri.queryParameters['state']
            
            // Verify state
            storedState = AWAIT SecureStorage.read('salesforce_state')
            IF state != storedState:
                THROW "Invalid state parameter"
            
            // Exchange code for tokens
            AWAIT exchangeCodeForTokens(authCode)
        CATCH error:
            LOG "Error handling auth callback: " + error
            THROW error
    END FUNCTION
    
    FUNCTION exchangeCodeForTokens(authCode):
        TRY:
            codeVerifier = AWAIT SecureStorage.read('salesforce_code_verifier')
            
            response = AWAIT CloudFunctions.call('exchangeSalesforceCode', {
                code: authCode,
                codeVerifier: codeVerifier
            })
            
            IF response.success:
                // Store tokens securely
                AWAIT SecureStorage.write('salesforce_access_token', response.accessToken)
                AWAIT SecureStorage.write('salesforce_refresh_token', response.refreshToken)
                AWAIT SecureStorage.write('salesforce_instance_url', response.instanceUrl)
                
                // Update auth state
                SET isConnected = true
                NOTIFY listeners
            ELSE:
                THROW response.error
        CATCH error:
            LOG "Error exchanging code for tokens: " + error
            THROW error
    END FUNCTION
    
    FUNCTION refreshAccessToken():
        TRY:
            refreshToken = AWAIT SecureStorage.read('salesforce_refresh_token')
            
            response = AWAIT CloudFunctions.call('refreshSalesforceToken', {
                refreshToken: refreshToken
            })
            
            IF response.success:
                AWAIT SecureStorage.write('salesforce_access_token', response.accessToken)
                RETURN response.accessToken
            ELSE:
                // Refresh token expired, need to re-authenticate
                AWAIT clearTokens()
                THROW "Refresh token expired"
        CATCH error:
            LOG "Error refreshing access token: " + error
            THROW error
    END FUNCTION
END CLASS
```

## 8. State Management (Riverpod)

```pseudocode
// Authentication Provider
authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => {
    return AuthNotifier()
})

// User Provider
userProvider = StreamProvider<AppUser?>((ref) => {
    auth = ref.watch(authProvider)
    IF auth.isAuthenticated:
        RETURN Firestore.collection('users').doc(auth.user.uid).snapshots()
            .map((doc) => AppUser.fromFirestore(doc))
    ELSE:
        RETURN Stream.value(null)
})

// Opportunities Provider (Reseller)
resellerOpportunitiesProvider = FutureProvider<List<SalesforceOpportunity>>((ref) => {
    user = ref.watch(userProvider).value
    IF user != null AND user.salesforceId != null:
        RETURN CloudFunctions.call('getResellerOpportunities', {
            resellerId: user.salesforceId
        }).then((response) => response.data)
    ELSE:
        RETURN []
})

// Chat Conversations Provider
chatConversationsProvider = StreamProvider<List<ChatConversation>>((ref) => {
    auth = ref.watch(authProvider)
    
    IF auth.isAdmin:
        RETURN Firestore.collection('conversations')
            .where('participants', 'array-contains', 'admin')
            .orderBy('lastMessageTime', 'desc')
            .snapshots()
            .map((snapshot) => snapshot.docs.map(ChatConversation.fromFirestore))
    ELSE:
        RETURN Firestore.collection('conversations')
            .where('participants', 'array-contains', auth.user.uid)
            .snapshots()
            .map((snapshot) => snapshot.docs.map(ChatConversation.fromFirestore))
})

// Service Submissions Provider (Admin)
serviceSubmissionsProvider = StreamProvider<List<ServiceSubmission>>((ref) => {
    RETURN Firestore.collection('service_submissions')
        .where('status', '==', 'PENDING')
        .orderBy('submittedAt', 'desc')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ServiceSubmission.fromFirestore))
})

// Theme Provider
themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) => {
    return ThemeNotifier(ref.watch(sharedPreferencesProvider))
})

CLASS ThemeNotifier EXTENDS StateNotifier<ThemeMode>:
    FUNCTION toggleTheme():
        newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light
        SET state = newMode
        AWAIT sharedPreferences.setString('theme_mode', newMode.toString())
    END FUNCTION
END CLASS
```

This comprehensive pseudo code covers all the major components and flows of the TwogetherApp, including authentication patterns, role-based features, Firebase integrations, Salesforce connectivity (both OAuth and JWT), real-time chat, file management, and state management. Each section shows the key logic and decision points for understanding how the application functions end-to-end. 