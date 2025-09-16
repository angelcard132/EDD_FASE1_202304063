unit login;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, SysUtils, menu_root, menu_usuario, lista_simple, json_loader, registro_usuario, globals;

procedure MostrarLogin;

implementation

var
  entryUsuario, entryPass: PGtkWidget;
  Usuarios: TListaUsuarios; // lista en memoria

procedure on_login_clicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  usuario, pass: String;
  u: PUsuario;
begin
  usuario := gtk_entry_get_text(GTK_ENTRY(entryUsuario));
  pass  := gtk_entry_get_text(GTK_ENTRY(entryPass));

  // ROOT (hardcodeado)
  if (usuario = 'root@edd.com') and (pass = 'root123') then
  begin
    WriteLn('Login ROOT OK');
    MostrarMenuRoot;
    Exit;
  end;

  // Usuario normal validando contra la lista
  u := BuscarUsuarioPorUsuario(Usuarios, usuario);
  if (u <> nil) and (u^.password = pass) then
  begin
    WriteLn('Login USUARIO OK: ', u^.usuario);
    CambiarUsuarioActivo(u^);  // Usar función que reinicia contactos
    MostrarMenuUsuario(u^);  // 🔹 ahora le pasamos el usuario logueado
  end
  else
  begin
    WriteLn('Credenciales inválidas');
  end;
  
end;

procedure on_register_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarRegistro(Usuarios);
end;

procedure MostrarLogin;
var
  window: PGtkWidget;
  vbox, hbox: PGtkWidget;
  lblUsuario, lblPass: PGtkWidget;
  btnLogin, btnRegister: PGtkWidget;
begin
  gtk_init(@argc, @argv);

  // Cargar SOLO usuarios en la lista global para que esté disponible en toda la app
  if FileExists('../assets/usuarios3.json') then
  begin
    WriteLn('🔄 Cargando usuarios desde usuarios3.json...');
    CargarUsuariosDesdeJSON('../assets/usuarios3.json', UsuariosGlobal);
  end
  else if FileExists('../assets/usuarios.json') then
  begin
    WriteLn('🔄 Cargando usuarios desde usuarios.json...');
    CargarUsuariosDesdeJSON('../assets/usuarios.json', UsuariosGlobal);
  end
  else
  begin
    WriteLn('⚠️ No se encontraron archivos de usuarios');
  end;

  // También cargar en la lista local para compatibilidad
  Usuarios := UsuariosGlobal;

  WriteLn('✅ Sistema iniciado - Los correos se crearán cuando los usuarios los envíen');

  // Ventana
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'EDDMail - Login');
  gtk_window_set_default_size(GTK_WINDOW(window), 320, 220);

  vbox := gtk_vbox_new(FALSE, 6);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Usuario
  lblUsuario := gtk_label_new('Usuario:');
  gtk_box_pack_start(GTK_BOX(vbox), lblUsuario, FALSE, FALSE, 0);
  entryUsuario := gtk_entry_new;
  gtk_box_pack_start(GTK_BOX(vbox), entryUsuario, FALSE, FALSE, 0);

  // Password
  lblPass := gtk_label_new('Contraseña:');
  gtk_box_pack_start(GTK_BOX(vbox), lblPass, FALSE, FALSE, 0);
  entryPass := gtk_entry_new;
  gtk_entry_set_visibility(GTK_ENTRY(entryPass), False);
  gtk_box_pack_start(GTK_BOX(vbox), entryPass, FALSE, FALSE, 0);

  // Botones
  hbox := gtk_hbox_new(TRUE, 6);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 0);

  btnLogin := gtk_button_new_with_label('Iniciar Sesión');
  g_signal_connect(btnLogin, 'clicked', G_CALLBACK(@on_login_clicked), nil);
  gtk_box_pack_start(GTK_BOX(hbox), btnLogin, TRUE, TRUE, 0);

  btnRegister := gtk_button_new_with_label('Crear Usuario');
  g_signal_connect(btnRegister, 'clicked', G_CALLBACK(@on_register_clicked), nil);
  gtk_box_pack_start(GTK_BOX(hbox), btnRegister, TRUE, TRUE, 0);

  gtk_widget_show_all(window);
  gtk_main;
end;

end.
