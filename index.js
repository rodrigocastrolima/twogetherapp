#!/usr/bin/env node

import { createServer, StdioTransport } from '@modelcontextprotocol/sdk';
import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs/promises';
import path from 'path';

const execAsync = promisify(exec);

// Create MCP server
const server = createServer({
  name: 'flutter-tools',
  tools: [
    {
      name: 'get_diagnostics',
      description: 'Get Flutter/Dart diagnostics for a file',
      inputSchema: {
        type: 'object',
        properties: {
          file: {
            type: 'string',
            description: 'Path to the Dart/Flutter file'
          }
        },
        required: ['file']
      },
      execute: async ({ file }) => {
        try {
          // Check if file exists
          await fs.access(file);
          
          // Run flutter analyze on the file
          const { stdout, stderr } = await execAsync(`flutter analyze ${file} --no-pub`);
          
          if (stderr) {
            return {
              diagnostics: stderr,
              status: 'error'
            };
          }
          
          return {
            diagnostics: stdout || 'No issues found',
            status: 'success'
          };
        } catch (error) {
          return {
            diagnostics: error.message,
            status: 'error'
          };
        }
      }
    },
    {
      name: 'apply_fixes',
      description: 'Apply Dart fix suggestions to a file',
      inputSchema: {
        type: 'object',
        properties: {
          file: {
            type: 'string',
            description: 'Path to the Dart/Flutter file'
          }
        },
        required: ['file']
      },
      execute: async ({ file }) => {
        try {
          // Check if file exists
          await fs.access(file);
          
          // Run dart fix on the file
          const { stdout, stderr } = await execAsync(`dart fix --apply ${file}`);
          
          if (stderr) {
            return {
              result: stderr,
              status: 'error'
            };
          }
          
          return {
            result: stdout || 'Applied fixes successfully',
            status: 'success'
          };
        } catch (error) {
          return {
            result: error.message,
            status: 'error'
          };
        }
      }
    }
  ]
});

// Start the server
const transport = new StdioTransport(server);
transport.listen(); 