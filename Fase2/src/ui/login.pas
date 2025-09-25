unit login;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader;

procedure MostrarLogin(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);

implementation

uses
  root_menu, menuusuario, registro_usuario; // <-- agregar registro_usuario

var
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;

  LoginWindow: PGtkWidget = nil;
  EntryEmail: PGtkWidget = nil;
  EntryPass: PGtkWidget = nil;

procedure OnIngresar(widget: PGtkWidget; data: gpointer); cdecl;
var
  email, pass: String;
  dialog: PGtkWidget;
  isValid: Boolean;
begin
  email := StrPas(gtk_entry_get_text(PGtkEntry(EntryEmail)));
  pass := StrPas(gtk_entry_get_text(PGtkEntry(EntryPass)));

  WriteLn('DEBUG - Email ingresado: "', email, '"');
  WriteLn('DEBUG - Password ingresado: "', pass, '"');

  // Validación ROOT primero
  if (email = 'root@edd.com') and (pass = 'root123') then
  begin
    WriteLn('DEBUG - Login como root exitoso');
    if Assigned(LoginWindow) then
      gtk_widget_destroy(LoginWindow);

    // Carga masiva inmediata al entrar como root
    CargaMasivaDesdeJSON('/home/angel/Desktop/EDD_FASE1_202304063/Fase2/assets/usuarios.json', 
                         '/home/angel/Desktop/EDD_FASE1_202304063/Fase2/assets/correos.json',
                         GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);

    // Abrir menú root
    root_menu.MostrarMenuRoot;
    Exit;
  end;

  // Login normal de usuario
  WriteLn('DEBUG - Validando credenciales de usuario...');
  isValid := ValidarLogin(email, pass);
  WriteLn('DEBUG - Resultado de ValidarLogin: ', isValid);
  
  if isValid then
  begin
    WriteLn('DEBUG - Credenciales válidas, abriendo menú usuario');
    if Assigned(LoginWindow) then
      gtk_widget_destroy(LoginWindow);
    menuusuario.MostrarMenuUsuario(email, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
  end
  else
  begin
    WriteLn('DEBUG - Credenciales inválidas');
    dialog := gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, GTK_MESSAGE_ERROR, GTK_BUTTONS_OK,
      PChar('Credenciales inválidas. Verifique email y password.' + LineEnding + 
            'Primero debe ingresar como root para cargar los usuarios.'));
    gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);
  end;
end;

procedure OnCrearCuenta(widget: PGtkWidget; data: gpointer); cdecl;
begin
  // Abrir ventana de registro
  MostrarRegistroUsuario(GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure MostrarLogin(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  vbox, form, hEmail, hPass, btnBox, btnBox2, lbl: PGtkWidget;
  btnIngresar, btnCancelar, btnCrearCuenta: PGtkWidget;
begin
  // Guardar referencias globales
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;

  // Si existe una ventana previa, destruirla
  if Assigned(LoginWindow) then
  begin
    gtk_widget_destroy(LoginWindow);
    LoginWindow := nil;
  end;

  // Limpiar campos de entrada
  EntryEmail := nil;
  EntryPass := nil;

  WriteLn('🔐 Creando nueva ventana de login...');
  
  LoginWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(LoginWindow), PChar('🔐 Login - EDDMail'));
  gtk_window_set_default_size(GTK_WINDOW(LoginWindow), 360, 280);
  gtk_window_set_position(GTK_WINDOW(LoginWindow), GTK_WIN_POS_CENTER);
  gtk_window_set_resizable(GTK_WINDOW(LoginWindow), False);

  // Conectar evento de cierre de ventana para salir de la aplicación
  g_signal_connect(LoginWindow, 'delete-event', G_CALLBACK(@gtk_main_quit), nil);

  vbox := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 16);
  gtk_container_add(GTK_CONTAINER(LoginWindow), vbox);

  lbl := gtk_label_new('Ingrese sus credenciales');
  gtk_box_pack_start(GTK_BOX(vbox), lbl, False, False, 0);

  form := gtk_vbox_new(False, 8);
  gtk_box_pack_start(GTK_BOX(vbox), form, True, True, 0);

  // Email
  hEmail := gtk_hbox_new(False, 6);
  gtk_box_pack_start(GTK_BOX(form), hEmail, False, False, 0);
  gtk_box_pack_start(GTK_BOX(hEmail), gtk_label_new('Email:'), False, False, 0);
  EntryEmail := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hEmail), EntryEmail, True, True, 0);

  // Password
  hPass := gtk_hbox_new(False, 6);
  gtk_box_pack_start(GTK_BOX(form), hPass, False, False, 0);
  gtk_box_pack_start(GTK_BOX(hPass), gtk_label_new('Password:'), False, False, 0);
  EntryPass := gtk_entry_new();
  gtk_entry_set_visibility(PGtkEntry(EntryPass), False);
  gtk_entry_set_invisible_char(PGtkEntry(EntryPass), Ord('*'));
  gtk_box_pack_start(GTK_BOX(hPass), EntryPass, True, True, 0);

  // Botones principales (Ingresar y Cancelar)
  btnBox := gtk_hbox_new(True, 10);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnIngresar := gtk_button_new_with_label('Ingresar');
  g_signal_connect(btnIngresar, 'clicked', G_CALLBACK(@OnIngresar), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnIngresar, True, True, 0);

  btnCancelar := gtk_button_new_with_label('Cancelar');
  g_signal_connect(btnCancelar, 'clicked', G_CALLBACK(@gtk_main_quit), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCancelar, True, True, 0);

  // Botón Crear Cuenta (separado)
  btnBox2 := gtk_hbox_new(False, 0);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox2, False, False, 5);

  btnCrearCuenta := gtk_button_new_with_label('Crear Cuenta');
  g_signal_connect(btnCrearCuenta, 'clicked', G_CALLBACK(@OnCrearCuenta), nil);
  gtk_box_pack_start(GTK_BOX(btnBox2), btnCrearCuenta, True, False, 0);

  WriteLn('🔓 Login mostrado correctamente');
  gtk_widget_show_all(LoginWindow);
end;

end.
