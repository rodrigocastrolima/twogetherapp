#!/usr/bin/env node

const { exec } = require('child_process');
const { promisify } = require('util');
const fs = require('fs').promises;
const path = require('path');

const execAsync = promisify(exec);

// Simple MCP protocol handler
const stdin = process.stdin;
const stdout = process.stdout;

stdin.setEncoding('utf8');

// Buffer to store incoming data
let buffer = '';

// Listen for data from stdin
stdin.on('data', async (chunk) => {
  buffer += chunk;
  
  // Process complete messages
  let newlineIndex;
  while ((newlineIndex = buffer.indexOf('\n')) !== -1) {
    const message = buffer.slice(0, newlineIndex);
    buffer = buffer.slice(newlineIndex + 1);
    
    try {
      const parsedMessage = JSON.parse(message);
      await handleMessage(parsedMessage);
    } catch (error) {
      sendResponse({
        error: `Failed to parse message: ${error.message}`,
      });
    }
  }
});

async function handleMessage(message) {
  // Check if it's a tool call
  if (message.type === 'tool_call') {
    const toolName = message.tool;
    const callId = message.id;
    const args = message.arguments || {};
    
    if (toolName === 'get_diagnostics') {
      await handleGetDiagnostics(callId, args);
    } else if (toolName === 'apply_fixes') {
      await handleApplyFixes(callId, args);
    } else {
      sendResponse({
        id: callId,
        error: `Unknown tool: ${toolName}`,
      });
    }
  } else if (message.type === 'init') {
    // Respond to init message
    sendResponse({
      type: 'init_response',
      server: {
        name: 'flutter-tools',
        version: '1.0.0',
        tools: [
          {
            name: 'get_diagnostics',
            description: 'Get Flutter/Dart diagnostics for a file',
            schema: {
              type: 'object',
              properties: {
                file: {
                  type: 'string',
                  description: 'Path to the Dart/Flutter file'
                }
              },
              required: ['file']
            }
          },
          {
            name: 'apply_fixes',
            description: 'Apply Dart fix suggestions to a file',
            schema: {
              type: 'object',
              properties: {
                file: {
                  type: 'string',
                  description: 'Path to the Dart/Flutter file'
                }
              },
              required: ['file']
            }
          }
        ]
      }
    });
  }
}

async function handleGetDiagnostics(callId, args) {
  const { file } = args;
  
  if (!file) {
    sendResponse({
      id: callId,
      error: 'File path is required'
    });
    return;
  }
  
  try {
    // Check if file exists
    await fs.access(file);
    
    // Run flutter analyze on the file
    const { stdout, stderr } = await execAsync(`flutter analyze ${file} --no-pub`);
    
    sendResponse({
      id: callId,
      result: {
        diagnostics: stdout || 'No issues found',
        status: stderr ? 'error' : 'success'
      }
    });
  } catch (error) {
    sendResponse({
      id: callId,
      error: error.message
    });
  }
}

async function handleApplyFixes(callId, args) {
  const { file } = args;
  
  if (!file) {
    sendResponse({
      id: callId,
      error: 'File path is required'
    });
    return;
  }
  
  try {
    // Check if file exists
    await fs.access(file);
    
    // Run dart fix on the file
    const { stdout, stderr } = await execAsync(`dart fix --apply ${file}`);
    
    sendResponse({
      id: callId,
      result: {
        result: stdout || 'Applied fixes successfully',
        status: stderr ? 'error' : 'success'
      }
    });
  } catch (error) {
    sendResponse({
      id: callId,
      error: error.message
    });
  }
}

function sendResponse(response) {
  stdout.write(JSON.stringify(response) + '\n');
}

// Handle process exit
process.on('SIGINT', () => {
  process.exit(0);
}); 