VERSION 5.00
Begin VB.Form Form1 
   Caption         =   "SCE Backup"
   ClientHeight    =   4575
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   7095
   LinkTopic       =   "Form1"
   ScaleHeight     =   4575
   ScaleWidth      =   7095
   StartUpPosition =   3  'Windows Default
   Begin VB.CommandButton btnOptions 
      Caption         =   "Options"
      Height          =   375
      Left            =   1560
      TabIndex        =   5
      Top             =   4080
      Width           =   1095
   End
   Begin VB.TextBox txtCurrentfile 
      Height          =   855
      Left            =   240
      MultiLine       =   -1  'True
      TabIndex        =   4
      Top             =   3120
      Width           =   6615
   End
   Begin VB.CommandButton btnStart 
      Caption         =   "Start"
      Height          =   375
      Left            =   240
      TabIndex        =   3
      Top             =   4080
      Width           =   1095
   End
   Begin VB.DirListBox lstStartIn 
      Height          =   2790
      Left            =   1800
      TabIndex        =   1
      Top             =   0
      Width           =   5055
   End
   Begin VB.Label lblCurrentFile 
      Caption         =   "Current File:"
      Height          =   255
      Left            =   240
      TabIndex        =   2
      Top             =   2760
      Width           =   975
   End
   Begin VB.Label lblDirectory 
      Caption         =   "Folder to backup:"
      Height          =   495
      Left            =   360
      TabIndex        =   0
      Top             =   240
      Width           =   1215
   End
End
Attribute VB_Name = "Form1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'
'
'
Dim FSys As New Scripting.FileSystemObject
Public hashobj As New MD5Hash

Public sINIFile As String
' These are configurable in .ini file
Public client_name As String
Public catalog_name As String
Public backup_server As String

Private Declare Function SafeArrayGetDim Lib "oleaut32.dll" (psa() As Any) As Long

' .INI File functions
Private Declare Function GetPrivateProfileString Lib "kernel32" Alias _
    "GetPrivateProfileStringA" (ByVal lpApplicationName _
    As String, ByVal lpKeyName As Any, ByVal lpDefault _
    As String, ByVal lpReturnedString As String, ByVal _
    nSize As Long, ByVal lpFileName As String) As Long

Private Declare Function WritePrivateProfileString Lib "kernel32" Alias _
    "WritePrivateProfileStringA" (ByVal lpApplicationName _
    As String, ByVal lpKeyName As Any, ByVal lpString As Any, _
    ByVal lpFileName As String) As Long

Public Function sGetINI(sINIFile As String, sSection As String, sKey _
    As String, sDefault As String) As String
    Dim sTemp As String * 256
    Dim nLength As Integer
    sTemp = Space$(256)
    nLength = GetPrivateProfileString(sSection, sKey, sDefault, sTemp, _
    255, sINIFile)
    sGetINI = Left$(sTemp, nLength)
End Function

Public Sub writeINI(sINIFile As String, sSection As String, sKey _
    As String, sValue As String)
    Dim n As Integer
    Dim sTemp As String
    sTemp = sValue
    'Replace any CR/LF characters with spaces
    For n = 1 To Len(sValue)
        If Mid$(sValue, n, 1) = vbCr Or Mid$(sValue, n, 1) = vbLf _
        Then Mid$(sValue, n) = " "
    Next n
    n = WritePrivateProfileString(sSection, sKey, sTemp, sINIFile)
End Sub


Private Sub btnOptions_Click()
    Dim OptionsForm As New Options
    Options.Show
End Sub

'
'
Private Sub Form_Load()
    'client_name = "USERPC-TEST"
    'catalog_name = "FIRST_BACKUP"
    'backup_server = "http://127.0.0.1:8080"
    Debug.Print ("Form1 - Form_Load()")
    sINIFile = App.Path & "\backup.ini"

    client_name = sGetINI(sINIFile, "Settings", "ClientName", "")
    catalog_name = sGetINI(sINIFile, "Settings", "CatalogName", "")
    backup_server = sGetINI(sINIFile, "Settings", "BackupServer", "")
    
    If (client_name = "" Or catalog_name = "" Or backup_server = "") Then
        a = MsgBox("backup.ini not found, please configure backup using the options button", vbCritical, "Error!")
    End If
End Sub


'
'
Private Sub btnStart_Click()
    
    Dim FolderSpec As String
    Set FSys = CreateObject("Scripting.FileSystemObject")
    
    FolderSpec = lstStartIn
    ScanFolder (FolderSpec)
    
End Sub
'
' Recursively traverse file tree
'
Sub ScanFolder(FolderSpec As String)
    
    Dim thisFolder As Folder
    Dim sFolders As Folders
    Dim fileItem As File, folderItem As Folder
    Dim AllFiles As Files
    Dim FilePath As String
    Dim arr() As Integer
    
    Set thisFolder = FSys.GetFolder(FolderSpec)
    Set sFolders = thisFolder.SubFolders
    Set AllFiles = thisFolder.Files
    
    For Each folderItem In sFolders
        ' Empty folders need to be saved similar to zero-byte files
        
        Debug.Print "Folder : " & folderItem.Path
        ScanFolder (folderItem.Path)
    Next
    
    For Each fileItem In AllFiles
        'Debug.Print "Current File: " & fileItem.Path & ", " & fileItem.size & " bytes"
        txtCurrentfile.Text = fileItem.Path & ", " & fileItem.size & " bytes"
        Me.Refresh
        arr = CommitFile(fileItem.Path)
        ' check if the list of needed blocks is empty
        If SafeArrayGetDim(arr) > 0 Then
            Debug.Print "Sendfile result: " & SendFile(fileItem.Path, arr)
        Else
            Debug.Print "Array returned by CommitFile(fileItemPath) contained zero elements"
        End If

    Next

End Sub
'
'
'
Function SendFile(InFileName As String, NeededBlocks() As Integer) As String
    
    Dim InFileHandle As Integer  ' File handle
    Dim FileSize As Long         ' Length of the file
    Dim Block() As Byte          ' Block of data
    Dim BlockSize As Long        ' Block size (default 4MB)
    Dim BlockCount As Long       ' How many block-sized blocks are in this file
    Dim LastBlockSize As Long    ' Size of any remainder block
    Dim Kbyte As Long            ' Helper for kilobyte
    Dim Mbyte As Long            ' Helper for megabyte
    Dim FilePosition As Long     ' Current position in file
    
    Kbyte = 1024
    Mbyte = 1024 * Kbyte
    BlockSize = 4 * Mbyte
    ReDim Block(BlockSize - 1)   ' Set our block size (4MB)
    Debug.Print "Filename: " & InFileName
    FileSize = FileLen(InFileName)
    BlockCount = FileSize \ BlockSize       ' Integer div
    LastBlockSize = FileSize Mod BlockSize  ' Remainder
    Debug.Print "******** SENDFILE() ********"
    Debug.Print "File is " & FileSize & " bytes long"
    Debug.Print "File has " & BlockCount + 1 & " blocks, last block is " & (FileSize Mod BlockSize) & " bytes"
   
    InFileHandle = FreeFile
    Open InFileName For Binary Access Read As #InFileHandle
    FilePosition = 1
    
    ' Need to check for empty array
    Debug.Print "Neededblocks: #"
    For i = 1 To UBound(NeededBlocks)
        Debug.Print NeededBlocks(i)
    Next i
    
    Dim thisBlock As Object
    ' Read each block
    Dim c As Integer
    For c = 1 To BlockCount
        Debug.Print "blockCount = " & BlockCount
        Debug.Print "Value " & c & " is in array: " & IsIntegerInArray(c, NeededBlocks)
        If IsIntegerInArray(c, NeededBlocks) Then
            ' Send this block with it's hash
            Get InFileHandle, FilePosition, Block ' read one block worth of data
            hash = ""
            hash = hashobj.HashBytes(Block)
            Debug.Print "SendFile - SendBlock result: " & SendBlock(Block)
        End If
        
        FilePosition = FilePosition + BlockSize
    Next c
    ' Read remainder block, if it exists
        Debug.Print "Value " & c & " is in array: " & IsIntegerInArray(c, NeededBlocks)
    If LastBlockSize > 0 Then
        ReDim Block(LastBlockSize - 1)        ' resize the block to read to match remainder block
        Debug.Print "Sending lastBlock"
        Debug.Print "blockCount = " & BlockCount
        Debug.Print "Value " & c & " is in array: " & IsIntegerInArray(c, NeededBlocks)
        If IsIntegerInArray(c, NeededBlocks) Then
            ' Send this block with it's hash
            Get InFileHandle, FilePosition, Block ' read one block worth of data
            hash = ""
            hash = hashobj.HashBytes(Block)
            Debug.Print "SendFile - SendBlock result: " & SendBlock(Block)
        End If
       
    End If
    Close #InFileHandle
    
    SendFile = "OK"
    
End Function
'
'
'
Function IsIntegerInArray(Value As Integer, arr() As Integer) As Boolean
    Dim i As Integer
    Dim found As Boolean
    found = False
    i = 1
    
    ' TODO check for empty array
    
    Do While i <= UBound(arr) And Not found
        If (arr(i) = Value) Then
            found = True
        Else
            i = i + 1
        End If
    Loop
    IsIntegerInArray = found
End Function
'
' Split file into blocks/hashes, attemp to commit to server
'
Function CommitFile(FileName As String) As Integer()
    
    Dim fso As New FileSystemObject
    Dim f As File
    Dim mtime, ctime, size As Long

    ' Collect file info
    Set f = fso.GetFile(FileName)
    mtime = Date2Long(f.DateLastModified)
    ctime = Date2Long(f.DateCreated)
    
    ' dictionary we are going to nest
    Dim dFileInfo As New Dictionary
    dFileInfo.Add "size", f.size
    dFileInfo.Add "filename", Replace(FileName, "\", "\\") ' Need to escape backslashes for JSON
    dFileInfo.Add "mtime", mtime
    dFileInfo.Add "ctime", ctime
    
    ' the main dictionary
    Dim dJSObject As New Dictionary
    dJSObject.Add "catalog", catalog_name
    dJSObject.Add "fileinfo", dFileInfo
    dJSObject.Add "client", client_name
    dJSObject.Add "commit", GenerateBlocklist(FileName)
    Debug.Print "Dict: " & Dict2JSON(dJSObject)
    jsonString = Dict2JSON(dJSObject)

    ' HTTP post this string
    Dim http As Object
    Set http = CreateObject("winhttp.winhttprequest.5.1")
    'http.SetProxy 2, "squid.saginawcontrol.com:3128"
    http.Open "POST", "http://" & backup_server & "/commit/", False
    http.SetRequestHeader "Content-Type", "application/json"
    http.Send jsonString
    
    Debug.Print "http.ResponseText = "; http.ResponseText
  
    If http.ResponseText = "OK" Then
        ' The server has all these blocks, we are good
        Dim BlankArray() As Integer
        CommitFile = BlankArray
    Else
        ' The server needs blocks and will return the list it needs
        Dim jsonResult As Object
        Dim NeededBlocks() As Integer
        Set jsonResult = parse(http.ResponseText)
        Debug.Print "jsonResult = " & jsonResult.Count
        ReDim NeededBlocks(jsonResult.Count)
        i = 1
        For Each key In jsonResult
            Debug.Print "key: " & key & ", " & " value: " & jsonResult(key)
            NeededBlocks(i) = jsonResult(key)
            i = i + 1
        Next
        CommitFile = NeededBlocks
    End If
    ' Result is either OK, or JSON containing list of needed blocks
    ' CommitFile = "Result from HTTP request"

End Function
'
' Add variable + value to a POST body (str) separated by boundary
'
' This does goofy stuff like mangle strings - DO NOT USE
'
Function AddMultipartVariable(VarName As String, VarValue As String, Boundary As String) As String
    
    Dim str As String
    str = ""
    str = str & "Content-Disposition: form-data; name=" & Chr(34) & VarName & Chr(34) & vbCrLf
    str = str & vbCrLf & VarValue & vbCrLf
    str = str & "--" & Boundary & vbCrLf
    AddMultipartVariable = str

End Function
'
' not using this one yet either
'
Function AddMultipartFile(FileName As String, FileData As String, Boundary As String) As String
    
    Dim str As String
    str = ""
    str = str & "Content-Disposition: form-data; name=" & Chr(34) & Name & Chr(34) & vbCrLf
    str = str & vbCrLf & Value & vbCrLf
    str = str & "--" & Boundary & vbCrLf
    AddMultipartVariable = str

End Function
'
' POST a block of data to the server with it's hash
' Server should return 'OK' if successful
'
Function SendBlock(ByRef BlockData() As Byte) As String
    
    Dim sBoundary As String * 24
    sBoundary = RandomString(24)
    
    Dim BlockHash As String * 32
    Dim Base64EncodedBlock As String
    Base64EncodedBlock = EncodeBase64(BlockData)
    BlockHash = ""
    BlockHash = hashobj.HashBytes(BlockData)
    Debug.Print "BlockData size: " & (UBound(BlockData) - LBound(BlockData) + 1)
    
    Dim PostBody As String
    
    ' post /store/ data = hash:hex, files = file:data:BlockData
    Dim http As Object
    Set http = CreateObject("winhttp.winhttprequest.5.1")
    'http.SetProxy 2, "squid.saginawcontrol.com:3128"
    http.Open "POST", "http://" & backup_server & "/store/", False
    http.SetRequestHeader "Content-Type", "multipart/form-data" & ";boundary=" & sBoundary
    
    ' build the multipart/form-data... by hand :~(
    PostBody = PostBody & "--" & sBoundary & vbCrLf
    
    PostBody = PostBody & "Content-Disposition: form-data; name=" & Chr(34) & "hash" & Chr(34) & vbCrLf
    PostBody = PostBody & vbCrLf & BlockHash & vbCrLf
    PostBody = PostBody & "--" & sBoundary & vbCrLf
    
    PostBody = PostBody & "Content-Type: application/octet-stream" & vbCrLf
    PostBody = PostBody & "Content-Disposition: form-data; name=""file""; filename=" & Chr(34) & "upload.bin" & Chr(34) & vbCrLf
    PostBody = PostBody & "Content-Transfer-Encoding: base64" & vbCrLf & vbCrLf
    PostBody = PostBody & Base64EncodedBlock & vbCrLf & vbCrLf
    PostBody = PostBody & "--" & sBoundary & "--"
   
    http.Send PostBody
  
    'Debug.Print "********************"
    Debug.Print "SendBlock()"
    'Debug.Print "********************"
    'Debug.Print "Status: " & http.Status & ", " & http.StatusText
    'Debug.Print "********************"
    'Debug.Print "** PostBody START **"
    'Debug.Print vbCrLf & PostBody
    'Debug.Print "** PostBody END   **"
        
    SendBlock = http.ResponseText

End Function

'
' Read a file and calculate MD5 hash for each 4MB block
' Return an array of dictionaries
' { "hash": xyxyxyxyxyxy, "id": i }
'
Function GenerateBlocklist(InFileName As String) As Variant
    
    Dim InFileHandle As Integer  ' File handle
    Dim FileSize As Long         ' Length of the file
    Dim Block() As Byte          ' Block of data
    Dim BlockSize As Long        ' Block size (default 4MB)
    Dim BlockCount As Long       ' How many block-sized blocks are in this file
    Dim BlockList() As Variant   ' Array of dictionaries
    Dim LastBlockSize As Long    ' Size of any remainder block
    Dim hash As String * 32      ' Current hash value
    Dim Kbyte As Long            ' Helper for kilobyte
    Dim Mbyte As Long            ' Helper for megabyte
    Dim FilePosition As Long     ' Current position in file
    
    Kbyte = 1024
    Mbyte = 1024 * Kbyte
    BlockSize = 4 * Mbyte
    ReDim Block(BlockSize - 1)   ' Set our block size (4MB)
    FileSize = FileLen(InFileName)
    BlockCount = FileSize \ BlockSize       ' Integer div
    LastBlockSize = FileSize Mod BlockSize  ' Remainder
    ReDim BlockList(BlockCount)
    Debug.Print "File is " & FileSize & " bytes long"
    Debug.Print "File has " & BlockCount + 1 & " blocks, last block is " & (FileSize Mod BlockSize) & " bytes"
    
    InFileHandle = FreeFile
    Open InFileName For Binary Access Read As #InFileHandle
    FilePosition = 1
    
    Dim thisBlock As Object
    ' Read each block
    For c = 1 To BlockCount
        Get InFileHandle, FilePosition, Block ' read one block worth of data
        hash = ""
        hash = hashobj.HashBytes(Block)
        FilePosition = FilePosition + BlockSize
        
        Set thisBlock = New Dictionary
        thisBlock.Add "hash", hash
        thisBlock.Add "id", c
        Set BlockList(c) = thisBlock
    Next c
    ' Read remainder block, if it exists
    If LastBlockSize > 0 Then
        ReDim Preserve BlockList(BlockCount + 1)  ' add one more to the blocklist
        ReDim Block(LastBlockSize - 1)        ' resize the block to read to match remainder block
        
        Get InFileHandle, FilePosition, Block
        hash = ""
        hash = hashobj.HashBytes(Block)
        
        Set thisBlock = New Dictionary
        thisBlock.Add "hash", hash
        thisBlock.Add "id", BlockCount + 1
        Set BlockList(BlockCount + 1) = thisBlock
    End If
    
    ' Zero-byte file
    If LastBlockSize = 0 And BlockCount = 0 Then
        Debug.Print "Zero-byte file"
        Set thisBlock = New Dictionary
        ReDim BlockList(1)
        thisBlock.Add "hash", ""
        thisBlock.Add "id", 1
        Set BlockList(1) = thisBlock
    End If
    
    Close #InFileHandle
    GenerateBlocklist = BlockList

End Function

'
' We should never have to do these on the client. Only the server cares
' about where the file is actually stored on the backup server.
'
Function HashStringtoDir(hashString As String)
    ' Create a directory string from a hash such as "8C285E60F2D671A41A10B2F2D37A12A9"
    ' Into a levels-deep nested directory - "8\C\2\8"
    
    Dim dirString As String
    Dim levels As Integer
    levels = 4
    dirString = ""
    For i = 1 To levels
        dirString = dirString & Mid(hashString, i, 1) & "\"
    Next i
    HashStringtoDir = dirString

End Function
Function HashStringtoFilename(hashString As String)
    ' Create a file name from a hash such as "8C285E60F2D671A41A10B2F2D37A12A9"
    ' Skipping the levels-deep directory - "5E60F2D671A41A10B2F2D37A12A9"
    
    Dim InFileName As String
    Dim levels As Integer
    levels = 4
    HashStringtoFilename = Mid(hashString, levels + 1, Len(hashString) - levels)

End Function

'
' Convert a Dictionary type to JSON
' Supports nested dictionaries
'
Function Dict2JSON(dict As Dictionary)
    
    Dim str As String
    str = " { "
    For Each key In dict.keys
        ' write this key
        ' "somekey" :
        str = str & Chr(34) & key & Chr(34) & ": "
        
        If IsArray(dict(key)) Then
            ' arrays are wrapped in square brackets
            str = str & " [ "
            
            Dim element As Integer
            For element = 1 To UBound(dict(key))
                ' this is the only way it seems to work
                ' dict(key)(x) is not recognized as an dict on it's own
                Dim d As Object
                Set d = dict(key)(element)
                str = str & Dict2JSON(d)
                str = str & ", "
            Next
            
            str = Left(str, Len(str) - 2)
            str = str & " ] "
        ElseIf TypeOf dict(key) Is Dictionary Then
            ' nested dictionary requires recursion
            str = str & Dict2JSON(dict(key))
        Else
            ' just a regular value, write it out:
            If VarType(dict(key)) = vbString Then
                ' enclose strings in quotes
                str = str & Chr(34) & dict(key) & Chr(34)
            Else
                str = str & dict(key)
            End If
        End If
        
        str = str & ", "
    Next
    ' remove the last comma+space
    str = Left(str, Len(str) - 2)
    str = str & " } "
    Dict2JSON = str

End Function

Private Function Long2Date(lngDate As Long) As Date
    
    Long2Date = lngDate / 86400# + #1/1/1970#

End Function

Private Function Date2Long(dtmDate As Date) As Long
    
    Date2Long = (dtmDate - #1/1/1970#) * 86400

End Function
'
'
'
Public Function ReadFileIntoString(strFilePath As String) As String
    
    Dim fso As New FileSystemObject
    Dim ts As TextStream

    Set ts = fso.OpenTextFile(strFilePath)
    ReadFileIntoString = ts.ReadAll

End Function

'
' Random string generator for multipart boundaries
'
Function RandomString(length As Integer) As String

    Randomize
    Dim chars As String
    Dim result As String
    result = ""
    chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    Dim i As Long
    For i = 1 To length
        result = result & Mid$(chars, Int(Rnd() * 62) + 1, 1)
    Next
    RandomString = result

End Function

Private Function EncodeBase64(bytes) As String
  Dim DM, EL
  Set DM = CreateObject("Microsoft.XMLDOM")
  ' Create temporary node with Base64 data type
  Set EL = DM.createElement("tmp")
  EL.DataType = "bin.base64"
  ' Set bytes, get encoded String
  EL.NodeTypedValue = bytes
  EncodeBase64 = EL.Text
End Function


