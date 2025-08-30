unit login;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, SysUtils, lista_simple, lista_doble, json_loader, menu_usuario, redactar;

var
  UsuariosGlobal: TListaUsuarios;
  CorreosGlobal: TListaCorreos;

procedure MostrarLogin;

implementation

var
  entryEmail, entryPass: PGtkWidget;

procedure on_login_clicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  email, pass: String;
  u: PUsuario;
begin
  email := gtk_entry_get_text(GTK_ENTRY(entryEmail));
  pass  := gtk_entry_get_text(GTK_ENTRY(entryPass));

  WriteLn('Intentando login con email: "', email, '" y password: "', pass, '"');

  // Validar usuario contra la lista
  u := BuscarUsuarioPorEmail(UsuariosGlobal, email);
  if u <> nil then
  begin
    WriteLn('Usuario encontrado: "', u^.email, '" con password: "', u^.password, '"');
    if u^.password = pass then
    begin
      WriteLn('Login exitoso: ', u^.email);
      WriteLn('Bienvenido: ', u^.nombre);
      
      // Pasar las listas globales al menu_usuario
      menu_usuario.SetGlobalData(UsuariosGlobal, CorreosGlobal);
      menu_usuario.CorreosGlobal := CorreosGlobal;
      
      // Set the global reference in redactar
      SetGlobalCorreosRef(CorreosGlobal);
      
      // Abrir menú de usuario
      MostrarMenuUsuario(u^);
    end
    else
    begin
      WriteLn('Password incorrecto. Esperado: "', u^.password, '", Recibido: "', pass, '"');
    end;
  end
  else
  begin
    WriteLn('Usuario no encontrado para email: "', email, '"');
    WriteLn('Usuarios disponibles:');
    MostrarUsuarios(UsuariosGlobal);
  end;
end;

procedure MostrarLogin;
var
  window: PGtkWidget;
  vbox: PGtkWidget;
  lblEmail, lblPass: PGtkWidget;
  btnLogin: PGtkWidget;
begin
  gtk_init(@argc, @argv);

  // Inicializar listas
  InicializarListaUsuarios(UsuariosGlobal);
  InicializarListaCorreos(CorreosGlobal);

  // Cargar usuarios desde JSON - fix the path
  if FileExists('/home/angel/Desktop/EDD_FASE1_202304063/Tareas/Tarea 1/usuarios2.json') then
  begin
    WriteLn('Cargando usuarios desde usuarios2.json...');
    CargarUsuariosDesdeJSON('/home/angel/Desktop/EDD_FASE1_202304063/Tareas/Tarea 1/usuarios2.json', UsuariosGlobal);
  end
  else
  begin
    WriteLn('No se encontró usuarios2.json, cargando usuarios de prueba...');
    // Usuarios de prueba como fallback
    InsertarUsuario(UsuariosGlobal, 1, 'Juan Pérez', 'jperez', 'pass123', 'juan@example.com', '12345678');
    InsertarUsuario(UsuariosGlobal, 2, 'María García', 'mgarcia', 'pass456', 'maria@example.com', '87654321');
  end;

  // Cargar correos desde JSON - fix the path
  if FileExists('/home/angel/Desktop/EDD_FASE1_202304063/Tareas/Tarea 1/correos2.json') then
  begin
    WriteLn('Cargando correos desde correos2.json...');
    CargarCorreosDesdeJSON2('/home/angel/Desktop/EDD_FASE1_202304063/Tareas/Tarea 1/correos2.json', CorreosGlobal, UsuariosGlobal);
  end
  else
  begin
    WriteLn('No se encontró correos2.json');
  end;

  // Crear ventana de login
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Sistema de Correos - Login');
  gtk_window_set_default_size(GTK_WINDOW(window), 320, 180);

  vbox := gtk_vbox_new(FALSE, 10);
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

  // Botón login
  btnLogin := gtk_button_new_with_label('Iniciar Sesión');
  g_signal_connect(btnLogin, 'clicked', G_CALLBACK(@on_login_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnLogin, FALSE, FALSE, 10);

  gtk_widget_show_all(window);
  gtk_main;
end;

end.
