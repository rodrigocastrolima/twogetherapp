const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const { promisify } = require('util');

const execPromise = promisify(exec);

// Configuration
const INPUT_FILE = 'docs/authentication_flow_diagram.md';
const OUTPUT_DIR = 'docs';
const TEMP_DIR = 'temp_diagrams';

// Ensure directories exist
if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}
if (!fs.existsSync(TEMP_DIR)) {
    fs.mkdirSync(TEMP_DIR, { recursive: true });
}

const extractAndExportDiagram = async () => {
    console.log(`Reading file: ${INPUT_FILE}`);
    
    try {
        const content = fs.readFileSync(INPUT_FILE, 'utf8');
        
        // Extract Mermaid diagram content between ```mermaid and ``` (handle Windows line endings)
        const diagramMatch = content.match(/```mermaid\r?\n([\s\S]*?)\r?\n```/);
        
        if (!diagramMatch) {
            console.error('No Mermaid diagram found in the file');
            return;
        }
        
        const diagramContent = diagramMatch[1];
        console.log('Found Mermaid diagram, extracting...');
        
        // Create temporary .mmd file
        const tempFile = path.join(TEMP_DIR, 'authentication_flow.mmd');
        const outputFile = path.join(OUTPUT_DIR, 'authentication_flow_diagram.pdf');
        
        console.log(`Writing diagram to temporary file: ${tempFile}`);
        fs.writeFileSync(tempFile, diagramContent);
        
        // Convert to PDF using mmdc
        console.log('Converting diagram to PDF...');
        const cmd = `npx mmdc -i "${tempFile}" -o "${outputFile}" -b transparent -s 2`;
        console.log(`Executing: ${cmd}`);
        
        const { stdout, stderr } = await execPromise(cmd);
        
        if (stdout) console.log('Output:', stdout);
        if (stderr && !stderr.includes('warn')) console.error('Errors:', stderr);
        
        console.log(`✅ Successfully generated: ${outputFile}`);
        
        // Also save the standalone .mmd file for reference
        const standaloneMmdFile = path.join(OUTPUT_DIR, 'authentication_flow_diagram.mmd');
        fs.copyFileSync(tempFile, standaloneMmdFile);
        console.log(`📄 Saved standalone diagram file: ${standaloneMmdFile}`);
        
    } catch (error) {
        console.error('❌ Error processing diagram:', error.message);
        throw error;
    }
};

// Main execution
const main = async () => {
    try {
        await extractAndExportDiagram();
        console.log('\n🎉 Export complete!');
    } catch (error) {
        console.error('❌ Export failed:', error.message);
        process.exit(1);
    } finally {
        // Cleanup temporary directory
        console.log('🧹 Cleaning up temporary files...');
        if (fs.existsSync(TEMP_DIR)) {
            fs.rmSync(TEMP_DIR, { recursive: true, force: true });
        }
        console.log('✨ Cleanup complete');
    }
};

main(); 