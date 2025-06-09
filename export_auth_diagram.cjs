const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const { promisify } = require('util');

const execPromise = promisify(exec);

// Configuration
const INPUT_FILE = 'docs/salesforce_dual_auth_diagram.mmd';
const OUTPUT_DIR = 'docs';
const TEMP_DIR = 'temp_diagrams';

// Ensure directories exist
if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}
if (!fs.existsSync(TEMP_DIR)) {
    fs.mkdirSync(TEMP_DIR, { recursive: true });
}

const exportAuthDiagram = async () => {
    console.log(`Reading file: ${INPUT_FILE}`);
    
    try {
        const diagramContent = fs.readFileSync(INPUT_FILE, 'utf8');
        console.log('Found Mermaid diagram, processing...');
        
        // Create temporary .mmd file
        const tempFile = path.join(TEMP_DIR, 'salesforce_auth_diagram.mmd');
        const outputFile = path.join(OUTPUT_DIR, 'salesforce_dual_auth_diagram.pdf');
        
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
        
        // File info
        const stats = fs.statSync(outputFile);
        const fileSizeKB = Math.round(stats.size / 1024);
        console.log(`📊 File size: ${fileSizeKB} KB`);
        
    } catch (error) {
        console.error('❌ Error processing diagram:', error.message);
        throw error;
    }
};

// Main execution
const main = async () => {
    try {
        await exportAuthDiagram();
        console.log('\n🎉 Authentication diagram export complete!');
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