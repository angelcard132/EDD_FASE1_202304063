unit login;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, menu_root, menu_usuario, lista_simple, json_loader, registro_usuario;

procedure MostrarLogin;

implementation

var
  entryEmail, entryPass: PGtkWidget;
  Usuarios: TListaUsuarios; // lista en memoria

procedure on_login_clicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  email, pass: String;
  u: PUsuario;
begin
  email := gtk_entry_get_text(GTK_ENTRY(entryEmail));
  pass  := gtk_entry_get_text(GTK_ENTRY(entryPass));

  // ROOT (hardcodeado)
  if (email = 'root@edd.com') and (pass = 'root123') then
  begin
    WriteLn('Login ROOT OK');
    MostrarMenuRoot;
    Exit;
  end;

  // Usuario normal validando contra la lista
  u := BuscarUsuarioPorEmail(Usuarios, email);
  if (u <> nil) and (u^.password = pass) then
  begin
    WriteLn('Login USUARIO OK: ', u^.email);
    MostrarMenuUsuario; // Más adelante le pasamos el usuario para filtrar bandeja
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
  lblEmail, lblPass: PGtkWidget;
  btnLogin, btnRegister: PGtkWidget;
begin
  gtk_init(@argc, @argv);

  // Inicializar y cargar usuarios desde JSON
  InicializarListaUsuarios(Usuarios);
  // Ajusta la ruta según tu estructura (si estás corriendo desde src/, ../assets/usuarios.json es correcto)
  CargarUsuariosDesdeJSON('../assets/usuarios.json', Usuarios);

  // Ventana
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'EDDMail - Login');
  gtk_window_set_default_size(GTK_WINDOW(window), 320, 220);

  vbox := gtk_vbox_new(FALSE, 6);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Email
  lblEmail := gtk_label_new('Correo:');
  gtk_box_pack_start(GTK_BOX(vbox), lblEmail, FALSE, FALSE, 0);
  entryEmail := gtk_entry_new;
  gtk_box_pack_start(GTK_BOX(vbox), entryEmail, FALSE, FALSE, 0);

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
