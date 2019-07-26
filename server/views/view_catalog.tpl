<link type="text/css" href="/static/css/default.css" rel="stylesheet">

%import datetime as datetime
%import humanfriendly
%import bottle
%import urllib.parse

%if client_id is None:
  <h3>You didn't tell me which client to view</h3>
%elif catalog_id is None:
  <h3>You didn't tell me which catalog to view</h3>
%else:
  <h3>Showing catalog {{catalog_id}} for client {{client_id}}</h3>
  <table class="ftable" border="1">
    %if file_list is None:
      <pre>I have no catalogs for this client.</pre>
    %else:
      <tr><th></th><th>File Name</th><th>Modified</th><th>Size</th><th>Blocklist ID</th></tr>
      %for f in file_list:
        <tr>
          <td><a href='/restore_file/{{ client_id }}/{{ catalog_id }}/{{ f[4] }}'><img src='/static/img/download_icon.png'></img></a></td>
          <td>{{ f[0] }}</td>
          <td>{{ datetime.datetime.fromtimestamp(f[1]).strftime('%a, %b %d, %Y %I:%M%p') }}</td>
          <td>{{ humanfriendly.format_size(f[2]) }}</td>
          <td>{{ f[3] }}</a></td>
        </tr>
      %end
  </table>
%end
