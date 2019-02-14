<link type="text/css" href="/static/css/default.css" rel="stylesheet">

%import datetime as datetime

%if client_id is None:
    <h3>I have backups for:</h3>
    <table class="ftable" border="1">
      <tr><th>Client ID</th></tr>
      %for c in client_list:
      <tr>
        <td><a href="{{ c }}">{{ c }}</a></td>
      </tr>
      %end
    </table>
%else:
    <h3>Showing backups for client {{client_id}}</h3>
    <p>
    %if len(catalogs) < 1:
      <pre>
      Could not find any catalogs for that client.
      </pre>
    </p>
    %else:
    <table class="ftable" border="1">
      <tr><th>Catalog ID</th><th>Created</th><th>.db file</th></tr>
      %for c in catalogs:
      <tr>
        <td><a href="{{c['link_url']}}">{{ c['link_label'] }}</a></td>
        <td>{{ c['backup_created'] }}</td>
        <td><a href="{{c['download_url']}}">DOWNLOAD</a></td>
      </tr>
      %end
    </table>
    %end
%end
