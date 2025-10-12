unit login;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  json_loader, menuusuario, root_menu, registro_usuario, // ✅ AGREGAR registro_usuario
  listasimple2, cola2, arbol_avl, arbol_b, blockchain, pila2, control_login;

procedure MostrarLogin(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var blockchainMail: TBlockchain);

implementation

var
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  GBlockchain: ^TBlockchain = nil;
  GPapelera: TPila; // ✅ DECLARAR GPapelera como variable local

  LoginWindow: PGtkWidget = nil;
  EntryEmail: PGtkWidget = nil;
  EntryPassword: PGtkWidget = nil;

procedure OnLogin(widget: PGtkWidget; data: gpointer); cdecl;
var
  email, password: String;
  nombre: String;
begin
  email := StrPas(gtk_entry_get_text(PGtkEntry(EntryEmail)));
  password := StrPas(gtk_entry_get_text(PGtkEntry(EntryPassword)));
  
  WriteLn('🔐 Intento de login: ', email);
  
  // ✅ VERIFICAR CREDENCIALES ROOT PRIMERO
  if (email = 'root') and (password = 'admin123') then
  begin
    WriteLn('👑 LOGIN ROOT EXITOSO');
    
    // ✅ REGISTRAR ENTRADA DE ROOT
    RegistrarEntrada('root@sistema.admin');
    
    // Mostrar menú root
    if Assigned(LoginWindow) then
      gtk_widget_destroy(LoginWindow);
    
    MostrarMenuRoot(GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GBlockchain^);
    Exit;
  end;
  
  // Verificar credenciales de usuario normal
  if ValidarLogin(email, password) then
  begin
    nombre := NombreDeEmail(email);
    WriteLn('✅ LOGIN EXITOSO: ', email, ' (', nombre, ')');
    
    // ✅ REGISTRAR ENTRADA DE USUARIO
    RegistrarEntrada(email);
    
    // Cerrar ventana de login
    if Assigned(LoginWindow) then
      gtk_widget_destroy(LoginWindow);
    
    // Mostrar menú de usuario con papelera - ✅ CORREGIR: usar GPapelera local
    MostrarMenuUsuario(email, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GPapelera, GBlockchain^);
  end
  else
  begin
    WriteLn('❌ LOGIN FALLIDO: ', email);
    gtk_message_dialog_new(nil,
      GTK_DIALOG_MODAL,
      GTK_MESSAGE_ERROR,
      GTK_BUTTONS_OK,
      PChar('❌ Credenciales incorrectas' + #10 + #10 +
            'Usuario o contraseña inválidos.' + #10 +
            'Para acceso root usa: root / admin123'));
  end;
end;

procedure OnRegistrarse(widget: PGtkWidget; data: gpointer); cdecl;
begin
  // ✅ CORREGIR: llamar a la función correcta
  MostrarRegistroUsuario(GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnSalir(widget: PGtkWidget; data: gpointer); cdecl;
begin
  gtk_main_quit();
end;

function OnDeleteEvent(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  gtk_main_quit();
  Result := False;
end;

procedure MostrarLogin(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var blockchainMail: TBlockchain);
var
  vbox, form, hbox, btnBox: PGtkWidget;
  lblTitulo, lblSubtitulo, lblEmail, lblPassword: PGtkWidget;
  btnLogin, btnRegistro, btnSalir: PGtkWidget;
begin
  // Guardar referencias globales
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;
  GBlockchain := @blockchainMail;
  
  // ✅ INICIALIZAR papelera local
  InicializarPila(GPapelera);

  WriteLn('🔑 Mostrando pantalla de login...');
  
  // Si existe una ventana previa, destruirla
  if Assigned(LoginWindow) then
    gtk_widget_destroy(LoginWindow);

  LoginWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(LoginWindow), PChar('Login - EDDMail con Blockchain'));
  gtk_window_set_default_size(GTK_WINDOW(LoginWindow), 400, 300);
  gtk_window_set_position(GTK_WINDOW(LoginWindow), GTK_WIN_POS_CENTER);
  gtk_window_set_resizable(GTK_WINDOW(LoginWindow), False);

  g_signal_connect(LoginWindow, 'delete-event', G_CALLBACK(@OnDeleteEvent), nil);

  vbox := gtk_vbox_new(False, 20);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 30);
  gtk_container_add(GTK_CONTAINER(LoginWindow), vbox);

  lblTitulo := gtk_label_new('📧 EDDMail con Blockchain');
  gtk_misc_set_alignment(GTK_MISC(lblTitulo), 0.5, 0.5);
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  lblSubtitulo := gtk_label_new('Sistema de Correos con Estructuras de Datos');
  gtk_misc_set_alignment(GTK_MISC(lblSubtitulo), 0.5, 0.5);
  gtk_box_pack_start(GTK_BOX(vbox), lblSubtitulo, False, False, 0);

  // Formulario de login
  form := gtk_vbox_new(False, 15);
  gtk_box_pack_start(GTK_BOX(vbox), form, True, True, 0);

  // Email
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblEmail := gtk_label_new('Email:');
  gtk_widget_set_size_request(lblEmail, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblEmail, False, False, 0);
  EntryEmail := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryEmail, True, True, 0);

  // Password
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblPassword := gtk_label_new('Password:');
  gtk_widget_set_size_request(lblPassword, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblPassword, False, False, 0);
  EntryPassword := gtk_entry_new();
  gtk_entry_set_visibility(PGtkEntry(EntryPassword), False);
  gtk_entry_set_invisible_char(PGtkEntry(EntryPassword), Ord('*'));
  gtk_box_pack_start(GTK_BOX(hbox), EntryPassword, True, True, 0);

  // Conectar Enter en password para hacer login
  g_signal_connect(EntryPassword, 'activate', G_CALLBACK(@OnLogin), nil);

  // Botones
  btnBox := gtk_hbox_new(True, 15);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnLogin := gtk_button_new_with_label('Iniciar Sesión');
  g_signal_connect(btnLogin, 'clicked', G_CALLBACK(@OnLogin), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnLogin, True, True, 0);

  btnRegistro := gtk_button_new_with_label('Registrarse');
  g_signal_connect(btnRegistro, 'clicked', G_CALLBACK(@OnRegistrarse), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnRegistro, True, True, 0);

  btnSalir := gtk_button_new_with_label('Salir');
  g_signal_connect(btnSalir, 'clicked', G_CALLBACK(@OnSalir), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnSalir, True, True, 0);

  gtk_widget_show_all(LoginWindow);
  
  WriteLn('✅ Login mostrado exitosamente');
  WriteLn('💡 Usa root/admin123 para acceso de administrador');
end;

end.
