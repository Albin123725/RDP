services:
  - type: web
    name: vnc-desktop
    env: docker
    dockerfilePath: ./Dockerfile
    plan: free
    autoDeploy: true
    healthCheckPath: /vnc_lite.html
    envVars:
      - key: VNC_RESOLUTION
        value: "1024x576"
      - key: VNC_DEPTH
        value: "16"
      # Add swap variables
      - key: ENABLE_SWAP
        value: "true"
      - key: SWAP_SIZE_GB
        value: "8"
    # REMOVED: resources: memoryMB: 512
    # Don't specify memory limit - let Render assign default
