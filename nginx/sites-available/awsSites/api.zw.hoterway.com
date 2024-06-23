server {

	root /home/ubuntu/zero_wait/api;

	# Add index.php to the list if you are using PHP
	#index index.html;

	server_name api.zw.hoterway.com;

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404
     		proxy_pass http://127.0.0.1:3015;
     		proxy_set_header X-Real-IP $remote_addr;
     		proxy_set_header HOST $http_host;
		#try_files $uri $uri/ =404;
	}



    


    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/api.zw.hoterway.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/api.zw.hoterway.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}


server {
    if ($host = api.zw.hoterway.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot




     # managed by Certbot


	#listen 80;
	#listen [::]:80;

	server_name api.zw.hoterway.com;
    return 404; # managed by Certbot
}

