unit login;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, blockchain, pila2, control_login, merkle_tree,
  json_loader, menuusuario, root_menu, registro_usuario; // ✅ AGREGAR merkle_tree y registro_usuario

procedure MostrarLogin(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var blockchainMail: TBlockchain);

implementation

var
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  GBlockchain: ^TBlockchain = nil;
  GPapelera: TPila; // ✅ AGREGAR papelera local
  GMerklePrivados: TArbolMerkle; // ✅ AGREGAR árbol de Merkle local
  
  LoginWindow: PGtkWidget = nil;
  EntryEmail: PGtkWidget = nil;
  EntryPassword: PGtkWidget = nil;

procedure MostrarMensaje(const titulo, mensaje: String; tipoMensaje: TGtkMessageType);
var
  dialog: PGtkWidget;
begin
  dialog := gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, tipoMensaje, GTK_BUTTONS_OK, PChar(mensaje));
  gtk_window_set_title(GTK_WINDOW(dialog), PChar(titulo));
  gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);
end;

procedure OnLogin(widget: PGtkWidget; data: gpointer); cdecl;
var
  email, password: String;
  validado: Boolean;
begin
  email := StrPas(gtk_entry_get_text(PGtkEntry(EntryEmail)));
  password := StrPas(gtk_entry_get_text(PGtkEntry(EntryPassword)));

  WriteLn('🔐 Intento de login: ', email);

  // Validación para root
  if (email = 'root') and (password = 'root123') then
  begin
    WriteLn('✅ Login ROOT exitoso');
    
    // ✅ REGISTRAR ENTRADA DE ROOT
    RegistrarEntrada('root@sistema.admin');
    
    // Cerrar ventana de login
    if Assigned(LoginWindow) then
      gtk_widget_destroy(LoginWindow);
    
    // Mostrar menú root CON TODAS LAS ESTRUCTURAS
    if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) and (GBlockchain <> nil) then
      MostrarMenuRoot(GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GBlockchain^);
    Exit;
  end;

  // Validación para usuarios normales
  validado := ValidarLogin(email, password);

  if validado then
  begin
    WriteLn('✅ Login exitoso para usuario: ', email);
    
    // ✅ REGISTRAR ENTRADA DEL USUARIO
    RegistrarEntrada(email);
    
    // Cerrar ventana de login
    if Assigned(LoginWindow) then
      gtk_widget_destroy(LoginWindow);
    
    // ✅ MOSTRAR MENÚ USUARIO CON MERKLE TREE
    if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) and (GBlockchain <> nil) then
      MostrarMenuUsuario(email, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GBlockchain^, GPapelera, GMerklePrivados);
  end
  else
  begin
    WriteLn('❌ Login fallido para: ', email);
    MostrarMensaje('Error de Autenticación', 'Email o contraseña incorrectos.', GTK_MESSAGE_ERROR);
  end;
end;

procedure OnMostrarRegistro(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) then
    MostrarRegistroUsuario(GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnSalir(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('👋 Saliendo de la aplicación...');
  gtk_main_quit();
end;

function OnDeleteEventLogin(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('👋 Cerrando aplicación desde login...');
  gtk_main_quit();
  Result := True;
end;

procedure MostrarLogin(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var blockchainMail: TBlockchain);
var
  vbox, form, hbox, btnBox: PGtkWidget;
  lblTitulo, lblEmail, lblPassword: PGtkWidget;
  btnLogin, btnRegistro, btnSalir: PGtkWidget;
begin
  // ✅ GUARDAR REFERENCIAS INCLUYENDO NUEVA PAPELERA Y MERKLE
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;
  GBlockchain := @blockchainMail;
  
  // ✅ INICIALIZAR ESTRUCTURAS FALTANTES LOCALMENTE
  InicializarPila(GPapelera);
  InicializarArbolMerkle(GMerklePrivados);

  WriteLn('🔧 DEBUG: Todas las estructuras inicializadas en login');

  // Si existe una ventana previa, destruirla
  if Assigned(LoginWindow) then
    gtk_widget_destroy(LoginWindow);

  LoginWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(LoginWindow), PChar('EDDMail - Iniciar Sesión'));
  gtk_window_set_default_size(GTK_WINDOW(LoginWindow), 400, 300);
  gtk_window_set_position(GTK_WINDOW(LoginWindow), GTK_WIN_POS_CENTER);
  gtk_window_set_resizable(GTK_WINDOW(LoginWindow), False);

  // ✅ CONECTAR DELETE EVENT PARA TERMINAR APLICACIÓN DESDE LOGIN
  g_signal_connect(LoginWindow, 'delete-event', G_CALLBACK(@OnDeleteEventLogin), nil);

  vbox := gtk_vbox_new(False, 20);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 30);
  gtk_container_add(GTK_CONTAINER(LoginWindow), vbox);

  lblTitulo := gtk_label_new('📧 EDDMail - Sistema de Correos');
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  form := gtk_vbox_new(False, 15);
  gtk_box_pack_start(GTK_BOX(vbox), form, True, True, 0);

  // Email
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblEmail := gtk_label_new('Email:');
  gtk_widget_set_size_request(lblEmail, 100, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblEmail, False, False, 0);
  EntryEmail := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryEmail, True, True, 0);

  // Password
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblPassword := gtk_label_new('Contraseña:');
  gtk_widget_set_size_request(lblPassword, 100, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblPassword, False, False, 0);
  EntryPassword := gtk_entry_new();
  gtk_entry_set_visibility(PGtkEntry(EntryPassword), False);
  gtk_entry_set_invisible_char(PGtkEntry(EntryPassword), Ord('*'));
  gtk_box_pack_start(GTK_BOX(hbox), EntryPassword, True, True, 0);

  // Botones
  btnBox := gtk_hbox_new(True, 15);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnLogin := gtk_button_new_with_label('Iniciar Sesión');
  g_signal_connect(btnLogin, 'clicked', G_CALLBACK(@OnLogin), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnLogin, True, True, 0);

  btnRegistro := gtk_button_new_with_label('Registrarse');
  g_signal_connect(btnRegistro, 'clicked', G_CALLBACK(@OnMostrarRegistro), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnRegistro, True, True, 0);

  btnSalir := gtk_button_new_with_label('Salir');
  g_signal_connect(btnSalir, 'clicked', G_CALLBACK(@OnSalir), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnSalir, True, True, 0);

  gtk_widget_show_all(LoginWindow);
  WriteLn('🔧 DEBUG: Login mostrado con todas las estructuras');
end;

end.
