import bottle
from bottle import route, run, template, get, post, request, static_file
from pathlib import Path
import os
import paste
import hashlib
import random
import datetime
import sqlite3
import glob
import base64

DB_FILE_EXTENSION = '.db'
CATALOG_BASE_PATH = 'D:\\Backups\\CATALOGS'
FILES_BASE_PATH = 'D:\\Backups\\FILES'
FILES_DIR_LAYERS = 4

KB = 1024
MB = 1024 * KB
BLOCK_SIZE = 4 * MB

#
# Database Stuff
#

def get_database_file_path(client_id):
	# return X:\backups\catalogs\hostname\ for (hostname)
	return os.path.join(CATALOG_BASE_PATH, client_id)

def get_database_file_name(catalog_id):
	return catalog_id + DB_FILE_EXTENSION

# create and return a SQLite connection object
def open_client_catalog(client_id, catalog_id):
	db_dir = get_database_file_path(client_id)
	db_file_name = get_database_file_name(catalog_id)
	db_full_file_path = os.path.join(db_dir, db_file_name)
	if not os.path.exists(db_dir):
		print("Need to create the directory to hold catalog " + db_dir)
		os.makedirs(db_dir)

	db = sqlite3.connect(db_full_file_path)

	db.execute('''
			CREATE TABLE IF NOT EXISTS catalog (
			id INTEGER PRIMARY KEY,
			filename TEXT,
			ctime REAL,
			mtime REAL,
			size INT,
			blocklist_id INT
		)
		''')
	db.commit()

	db.execute('''
		CREATE TABLE IF NOT EXISTS blocklist (
				id INTEGER PRIMARY KEY,
			blocklist_id INT,
			series INT,
			md5 TEXT
		)
		''')
	db.commit()
	return db

# close the SQLite Connection object
def close_client_catalog(db):
    db.close()

# split a hash up into dir+filename:
#   (abcdef12345, 4) becomes ('\\a\\b\\c\\d\\', 'ef12345')
# md5 = 32 bytes, sha256 = 64 bytes
def file_path_parts_from_hash(hash):
	dest_dir = ''
	for i in range(0, FILES_DIR_LAYERS):
		dest_dir = os.path.join(dest_dir, hash[i])
	dest_file_name = hash[FILES_DIR_LAYERS:]

	return(dest_dir, dest_file_name)

# same thing, but return a str instead of tuple
def file_path_from_hash(hash):
	t = file_path_parts_from_hash(hash)
	return os.path.join(FILES_BASE_PATH, t[0], t[1])

# check if a hash exists in our file storage
def does_file_hash_exist(file_hash):
	file_name = os.path.join(file_path_from_hash(file_hash))
	#print("Checking " + file_name)
	if os.path.isfile(file_name):
		#print('File ', file_path_from_hash(file_hash), 'DOES exist!')
		return True
	else:
		#print('File ', file_path_from_hash(file_hash), 'DOES NOT exist!')
		return False

def md5_hash_file_upload(fobj):
	hash_md5 = hashlib.md5()

	try:
		with fobj as f:
			for chunk in iter(lambda: f.read(4096), b""):
				hash_md5.update(chunk)
		return hash_md5.hexdigest()

	except:
		# let's do a real error capture/log here
		return "ERROR"


# Static Routes
@get("/static/client/<filepath:re:.*\.py>")
def client(filepath):
    return static_file(filepath, root="static/client")

@get("/static/css/<filepath:re:.*\.css>")
def css(filepath):
    return static_file(filepath, root="static/css")

@get("/static/img/<filepath:re:.*\.(jpg|png|gif|ico|svg)>")
def img(filepath):
    return static_file(filepath, root="static/img")

@get("/static/js/<filepath:re:.*\.js>")
def js(filepath):
    return static_file(filepath, root="static/js")

#
# Web Interface
#
@get('/')
def index():
	return template('index.tpl')

@get('/view/<client_id>', name='view_client')
def view_client(client_id):
    catalogs = os.path.join(CATALOG_BASE_PATH, client_id, '*' + DB_FILE_EXTENSION)
    catalogs = glob.glob(catalogs)
    catalog_list = []
    for c in catalogs:
        backup_created = os.stat(c).st_ctime
        backup_created = datetime.datetime.fromtimestamp(backup_created).strftime('%a, %b %d, %Y %I:%M%p')
        link_label = Path(c).name.rstrip('.db')
        catalog_id = Path(c).name.rstrip('.db')
        link_url = bottle.url('view_client_catalog', client_id=client_id, catalog_id=catalog_id)
        download_url = bottle.url('download_client_catalog', client_id=client_id, catalog_id=catalog_id)
        catalog_list.append({ 'link_url': link_url, 'link_label': link_label, 'backup_created': backup_created, 'download_url': download_url })

    return template('view_client.tpl', client_id=client_id, catalogs=catalog_list)


@get('/view/<client_id>/<catalog_id>', name='view_client_catalog')
def view_client_catalog(client_id, catalog_id):
    db = open_client_catalog(client_id, catalog_id)
    cursor = db.cursor()
    cursor.execute(''' SELECT filename, mtime, size, blocklist_id FROM catalog LIMIT 1000 ''')
    file_list = cursor.fetchall()
    close_client_catalog(db)
    return template('view_catalog.tpl', client_id=client_id, catalog_id=catalog_id, file_list=file_list)


@get('/download/<client_id>/<catalog_id>', name='download_client_catalog')
def download_client_catalog(client_id, catalog_id):
    db_dir = get_database_file_path(client_id)
    db_file_name = get_database_file_name(catalog_id)
    return static_file(db_file_name, root=db_dir, download=catalog_id+DB_FILE_EXTENSION)

@get('/view')
@get('/view/')
def view():
    client_list = []
    client_list = next(os.walk(CATALOG_BASE_PATH))[1]
    return template('view_client.tpl', client_list=client_list, client_id=None)

#
# API stuff
#
@route('/debug')
def index():
    return '<h2>DEBUG</h2>'

# attempt to commit file
@post('/commit/')
def commit():
	# recieve list of block_ID and hashes
	# send back list of ID's that don't exist on system
	# otherwise send back OK, create entry in catalog
	needed_blocks = {}
	existing_blocks = []
	block_count = 1

	# debugging
	#print('DEBUG:')
	#print(request.body.getvalue().decode('utf-8'))

	# zero-byte file, just save the entry
	if request.json['fileinfo']['size'] == 0:
		client_id = request.json['client']
		catalog_id = request.json['catalog']
		fi = request.json['fileinfo']

		catalog_db = open_client_catalog(client_id, catalog_id)
		cur = catalog_db.cursor()

		cur.execute('''
			SELECT * from catalog WHERE filename = :filename
		''',
			{ 'filename': fi['filename'] }
		)
		rst = cur.fetchone()
		if rst is not None:
			print('file already exists in catalog')
			return 'OK'
		# write this file info to catalog
		cur.execute('''
				INSERT INTO catalog(filename, ctime, mtime, size, blocklist_id)
				VALUES(:filename, :ctime, :mtime, :size, :blocklist_id)
			''',
			{ 'filename': fi['filename'],
			  'ctime': fi['ctime'],
			  'mtime': fi['mtime'],
			  'size': fi['size'],
			  'blocklist_id': 0 }
			)
		catalog_db.commit()

		close_client_catalog(catalog_db)
		return 'OK'

	try:
		for block in request.json['commit']:
			if does_file_hash_exist(block['hash']):
				existing_blocks.append(block['id'])
			else:
				needed_blocks.update({ block_count: block['id'] })
				block_count = block_count + 1
	except Exception as e:
		print("Error trying to /commit/: " + str(e))
		return "REQUEST_ERROR"

# Debugging
#	print(request.json)
#	print('Existing blocks: ', existing_blocks)
#	print('Needed blocks:   ', needed_blocks)

	if len(needed_blocks) > 0:
		return needed_blocks
	else: # maybe this should be it's own function...
		client_id = request.json['client']
		catalog_id = request.json['catalog']
		fi = request.json['fileinfo']
		blocklist_id = ''

		catalog_db = open_client_catalog(client_id, catalog_id)
		cur = catalog_db.cursor()

		cur.execute('''
			SELECT * from catalog WHERE filename = :filename
		''',
			{ 'filename': fi['filename'] }
		)
		rst = cur.fetchone()
		if rst is not None:
			print('file already exists in catalog')
			return 'OK'

		# get the next available blocklist_id
		cur.execute('''
				SELECT MAX(blocklist_id) from blocklist
			''')
		new_blocklist_id = cur.fetchone()[0]

		if new_blocklist_id is None:
		#	print('starting a new blocklist')
			new_blocklist_id = 1
		else:
		#	print('using existing blocklist')
			new_blocklist_id = int(new_blocklist_id) + 1

		#print('new_blocklist_id:', new_blocklist_id)

		# insert x rows in blocklist
		for block in request.json['commit']:
			cur.execute('''
				INSERT INTO blocklist(blocklist_id, series, md5)
				VALUES(:blocklist_id, :series, :md5)
			''',
				{ 'blocklist_id': new_blocklist_id,
				  'series': block['id'],
				  'md5': block['hash']
				}
			)
		catalog_db.commit()

		# write this file info to catalog
		cur.execute('''
				INSERT INTO catalog(filename, ctime, mtime, size, blocklist_id)
				VALUES(:filename, :ctime, :mtime, :size, :blocklist_id)
			''',
			{ 'filename': fi['filename'],
			  'ctime': fi['ctime'],
			  'mtime': fi['mtime'],
			  'size': fi['size'],
			  'blocklist_id': new_blocklist_id }
			)
		catalog_db.commit()

		close_client_catalog(catalog_db)
		return 'OK'

# receive single block function
@post('/store/')
def store():
	base64_file = False

	if 'hash' in request.forms:
		try:
			submitted_hash = request.forms.get('hash').lower() # someone might send us an uppercase hash
		except Exception as e:
			print("ERROR - MISSING HASH")
			return "ERROR"
	else:
		print("ERROR - MISSING HASH")
		return "ERROR"

	#print("Submitted hash:", submitted_hash)

	temp_file_name = os.path.join(FILES_BASE_PATH, str(random.randint(10000,99999)) + str(random.randint(100000,999999)))
	if os.path.exists(temp_file_name):
		print('temp_file_name: ' + temp_file_name + ' already exists, weird.')
		exit()

	try:
		block_data_file_obj = request.files.get('file')
	except Exception as e:
		print(e)
		print("ERROR - INVALID OR MISSING FILE")
		return "ERROR"

	if 'Content-Transfer-Encoding' in request.files.get('file').headers:
		if request.files.get('file').headers['Content-Transfer-Encoding'] == 'base64':
			base64_file = True

	if base64_file:
		h = hashlib.md5()
		b64DecodedData = base64.decodebytes(block_data_file_obj.file.read())
		h.update(b64DecodedData)
		uploaded_file_hash = h.hexdigest()
	else:
		block_data_file_obj.save(temp_file_name)
		uploaded_file_hash = md5_hash_file_upload(block_data_file_obj.file)

	if base64_file:
		new_file = open(temp_file_name, 'wb')
		new_file.write(b64DecodedData)
		new_file.close()

	#print("File size: " + os.fstat(temp_file_name).st_size)
	#print('submitted_hash  :', submitted_hash)
	#print('block_hash      :', uploaded_file_hash)
	# if our hash matches what we were sent, store the block
	if uploaded_file_hash == submitted_hash:
		file_name = file_path_from_hash(uploaded_file_hash)
		file_dir = os.path.join(FILES_BASE_PATH, file_path_parts_from_hash(uploaded_file_hash)[0])

		# we can reach here when a file has multiple, identical blocks
		if os.path.exists(file_name):
			print('File for this block already exists. Possibly identical in same file. Name: ' + file_name, ' temp file: ', temp_file_name)
			os.remove(temp_file_name)
			return 'OK'

		if not os.path.exists(file_dir):
			#print('Making directory ' + file_dir)
			os.makedirs(file_dir)

		try:
			os.rename(temp_file_name, file_name)
			print('temp_file_name = ' + temp_file_name + ' file_name = ' + file_name)
			return 'OK'
		except IOError as e:
			print('file error', e)
			return 'ERROR - error writing to disk'

		print('made it through try/except')
	else:
		print("ERROR - hashes do not match.\nUploaded file: " + uploaded_file_hash + "\nSubmitted hash: " + submitted_hash)
		return 'ERROR - hashes do not match'

# use the paste webserver as the basic one will cause strange errors
run(server='paste', host='0.0.0.0', port=8080, reloader=True, debug=True)
