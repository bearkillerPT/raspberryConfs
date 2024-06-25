server {

	root /home/pi/park2Charge/plug-here-website/build;


	# Add index.php to the list if you are using PHP
	index index.html;

	server_name plughere.app;
        server_name www.plughere.app;

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404
     		#proxy_pass http://127.0.0.1:3005;
     		#proxy_set_header X-Real-IP $remote_addr;
     		#proxy_set_header HOST $http_host;
		#error_page 404 403 500 503 /nginx404.html;
		try_files $uri $uri/ /index.html;

	}
	listen 443;
    ssl_certificate /etc/letsencrypt/live/bdl.bearkillerpt.xyz/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/bdl.bearkillerpt.xyz/privkey.pem; # managed by Certbot




}

#server {
#    if ($host = plughere.app) {
#        return 301 https://$host$request_uri;
#    } # managed by Certbot


     # managed by Certbot


#	listen 80;
#	listen [::]:80;

#	server_name plughere.app;


    #return 404; # managed by Certbot

#}
server {
    if ($host = plughere.app) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

    if ($host = www.plughere.app) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


	server_name plughere.app;
    listen 80;
    return 404; # managed by Certbot


}
