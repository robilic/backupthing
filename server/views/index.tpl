<link type="text/css" href="/static/css/default.css" rel="stylesheet">

%import socket
%import bottle

<h3>Backup server running on {{ socket.gethostname() }}</h3>
<p>Click <a href="{{ bottle.url('view_client', client_id='') }}">here</a> to view backups</p>
