#!/usr/bin/env python3

import http.server
import socketserver
import json
import subprocess
import os
import sys
import time
import threading
import tempfile
from urllib.parse import parse_qs, urlparse

PORT = 8081

class ProjectBuilderRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/build-project':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                request = json.loads(post_data.decode('utf-8'))
                
                # Extract parameters
                project_name = request.get('project_name')
                infrastructure_spec = request.get('infrastructure_spec', {})
                
                if not project_name:
                    self.send_error(400, "Missing project_name parameter")
                    return
                
                if not infrastructure_spec:
                    self.send_error(400, "Missing infrastructure_spec parameter")
                    return
                
                # Validate project name (alphanumeric, hyphens, underscores only)
                if not all(c.isalnum() or c in '-_' for c in project_name):
                    self.send_error(400, "Invalid project_name. Use only alphanumeric characters, hyphens, and underscores")
                    return
                
                # Generate a unique build ID
                build_id = str(int(time.time()))
                
                # Run project builder in a separate thread
                threading.Thread(target=self.build_project, 
                                 args=(project_name, infrastructure_spec, build_id)).start()
                
                # Send response
                self.send_response(202)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = {
                    'status': 'accepted',
                    'message': f'Project build for {project_name} started',
                    'build_id': build_id,
                    'log_file': f'/home/projectbuilder/logs/build-{project_name}-{build_id}.log',
                    'estimated_time': '30-60 seconds'
                }
                self.wfile.write(json.dumps(response).encode())
                
            except json.JSONDecodeError:
                self.send_error(400, "Invalid JSON in request body")
            except Exception as e:
                self.send_error(500, f"Internal server error: {str(e)}")
                
        elif self.path == '/health':
            # Health check endpoint
            try:
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                
                # Check if required directories exist
                required_dirs = [
                    '/home/projectbuilder/projects',
                    '/home/projectbuilder/logs',
                    '/home/projectbuilder/scripts'
                ]
                
                health_status = {
                    'status': 'healthy',
                    'service': 'project-builder',
                    'version': '1.0.0',
                    'timestamp': time.time(),
                    'checks': {
                        'directories': all(os.path.exists(d) for d in required_dirs),
                        'generator_script': os.path.exists('/home/projectbuilder/scripts/generate-terraform.sh'),
                        'upload_script': os.path.exists('/opt/project-builder/build-and-upload.sh')
                    }
                }
                
                # Overall health based on checks
                if not all(health_status['checks'].values()):
                    health_status['status'] = 'degraded'
                
                self.wfile.write(json.dumps(health_status).encode())
                
            except Exception as e:
                self.send_error(500, f"Health check failed: {str(e)}")
                
        elif self.path == '/status':
            # Status endpoint to check recent builds
            try:
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                
                # Get recent log files
                logs_dir = '/home/projectbuilder/logs'
                recent_builds = []
                
                if os.path.exists(logs_dir):
                    for filename in sorted(os.listdir(logs_dir), reverse=True)[:10]:
                        if filename.startswith('build-') and filename.endswith('.log'):
                            filepath = os.path.join(logs_dir, filename)
                            stat = os.stat(filepath)
                            recent_builds.append({
                                'filename': filename,
                                'size': stat.st_size,
                                'modified': stat.st_mtime
                            })
                
                status = {
                    'service': 'project-builder',
                    'uptime': time.time(),
                    'recent_builds': recent_builds,
                    'logs_directory': logs_dir
                }
                
                self.wfile.write(json.dumps(status).encode())
                
            except Exception as e:
                self.send_error(500, f"Status check failed: {str(e)}")
        else:
            self.send_error(404, "Endpoint not found. Available endpoints: /build-project, /health, /status")
    
    def build_project(self, project_name, infrastructure_spec, build_id):
        """Build project in a separate thread"""
        try:
            # Create temporary file for infrastructure spec
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as temp_file:
                json.dump(infrastructure_spec, temp_file, indent=2)
                spec_file_path = temp_file.name
            
            # Run the project builder script
            result = subprocess.run([
                '/opt/project-builder/build-and-upload.sh',
                project_name,
                spec_file_path,
                build_id
            ], capture_output=True, text=True, timeout=300)  # 5 minute timeout
            
            # Clean up temporary file
            os.unlink(spec_file_path)
            
            if result.returncode != 0:
                print(f"Build failed for project {project_name}: {result.stderr}", file=sys.stderr)
            else:
                print(f"Build completed successfully for project {project_name}", file=sys.stdout)
                
        except subprocess.TimeoutExpired:
            print(f"Build timeout for project {project_name} (exceeded 5 minutes)", file=sys.stderr)
        except subprocess.CalledProcessError as e:
            print(f"Build process error for project {project_name}: {e}", file=sys.stderr)
        except Exception as e:
            print(f"Unexpected error building project {project_name}: {e}", file=sys.stderr)
    
    def log_message(self, format, *args):
        """Override to add timestamp to log messages"""
        sys.stderr.write("%s - %s - %s\n" %
                         (self.log_date_time_string(),
                          self.address_string(),
                          format % args))

def run_server():
    """Start the webhook server"""
    try:
        with socketserver.TCPServer(("", PORT), ProjectBuilderRequestHandler) as httpd:
            print(f"🚀 Project Builder webhook server starting on port {PORT}")
            print(f"📋 Available endpoints:")
            print(f"   POST /build-project - Build Terraform project from JSON spec")
            print(f"   GET  /health        - Health check")
            print(f"   GET  /status        - Recent builds status")
            print(f"🔧 Ready to accept requests...")
            httpd.serve_forever()
    except Exception as e:
        print(f"❌ Failed to start server: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    run_server()