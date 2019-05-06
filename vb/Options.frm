VERSION 5.00
Begin VB.Form Options 
   Caption         =   "Options"
   ClientHeight    =   3480
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   5625
   BeginProperty Font 
      Name            =   "MS Sans Serif"
      Size            =   9.75
      Charset         =   0
      Weight          =   400
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   LinkTopic       =   "Form2"
   ScaleHeight     =   3480
   ScaleWidth      =   5625
   StartUpPosition =   3  'Windows Default
   Begin VB.TextBox TxtCatalog 
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   360
      Left            =   1320
      TabIndex        =   4
      Top             =   1800
      Width           =   4095
   End
   Begin VB.CommandButton BtnOptionsCancel 
      Caption         =   "Cancel"
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   375
      Left            =   4440
      TabIndex        =   3
      Top             =   3000
      Width           =   975
   End
   Begin VB.CommandButton BtnOptionsOk 
      Caption         =   "OK"
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   375
      Left            =   240
      TabIndex        =   2
      Top             =   3000
      Width           =   975
   End
   Begin VB.TextBox TxtClient 
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   360
      Left            =   1320
      TabIndex        =   1
      Top             =   1080
      Width           =   4095
   End
   Begin VB.TextBox TxtServer 
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   360
      Left            =   1320
      TabIndex        =   0
      Top             =   360
      Width           =   4095
   End
   Begin VB.Label Label2 
      Caption         =   "IP or name + port, eg: SERVERNAME:8080"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   8.25
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   255
      Left            =   1440
      TabIndex        =   9
      Top             =   720
      Width           =   3975
   End
   Begin VB.Label Label1 
      Caption         =   "Click OK to save these settings to backup.ini"
      Height          =   375
      Left            =   840
      TabIndex        =   8
      Top             =   2400
      Width           =   4575
   End
   Begin VB.Label LblCatalog 
      Alignment       =   1  'Right Justify
      Caption         =   "Catalog"
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   255
      Index           =   1
      Left            =   120
      TabIndex        =   7
      Top             =   1800
      Width           =   975
   End
   Begin VB.Label LblClient 
      Alignment       =   1  'Right Justify
      Caption         =   "Client"
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   255
      Index           =   0
      Left            =   120
      TabIndex        =   6
      Top             =   1080
      Width           =   975
   End
   Begin VB.Label LblServer 
      Alignment       =   1  'Right Justify
      Caption         =   "Server"
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   255
      Index           =   0
      Left            =   120
      TabIndex        =   5
      Top             =   360
      Width           =   975
   End
End
Attribute VB_Name = "Options"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Private Sub BtnOptionsCancel_Click()
    Unload Me
End Sub

Private Sub BtnOptionsOk_Click()
    Form1.writeINI Form1.sINIFile, "Settings", "ClientName", TxtClient.Text
    Form1.writeINI Form1.sINIFile, "Settings", "CatalogName", TxtCatalog.Text
    Form1.writeINI Form1.sINIFile, "Settings", "BackupServer", TxtServer.Text
    Unload Me
End Sub

'
'
Private Sub Form_Load()
    TxtServer.Text = Form1.backup_server
    TxtClient.Text = Form1.client_name
    TxtCatalog.Text = Form1.catalog_name
End Sub

