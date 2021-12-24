#!/bin/bash

echo "Attempt to renew cert on $(date +'%d-%m-%Y')"
podman run --replace -it --name renew-cert -v $(pwd)/acme_cert:/acme.sh -v $(pwd)/web:/web -v $(pwd)/certs:/certs neilpang/acme.sh --cron

if podman logs renew-cert | grep Skipped; then
  echo "Skipped..."
else
  echo "Nginx config needs to be reloaded..."
  podman exec forum_web_1 service nginx force-reload
fi
echo "Done!"
