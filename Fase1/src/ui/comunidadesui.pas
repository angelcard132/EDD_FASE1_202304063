unit comunidadesui;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, SysUtils, lista_simple, comunidades;

procedure MostrarComunidades;
procedure CrearComunidad(widget: PGtkWidget; data: gpointer); cdecl;
procedure AgregarAComunidad(widget: PGtkWidget; data: gpointer); cdecl;

implementation

uses
  globals; // Move the import to implementation section to avoid circular dependency

var
  ventanaComunidades: PGtkWidget;
  txtNombre, txtComunidad, txtCorreo: PGtkWidget;

function ObtenerTextoDeTextView(textview: PGtkWidget): String;
var
  buffer: PGtkTextBuffer;
  iter_start, iter_end: TGtkTextIter;
  texto: PChar;
begin
  buffer := gtk_text_view_get_buffer(GTK_TEXT_VIEW(textview));
  gtk_text_buffer_get_start_iter(buffer, @iter_start);
  gtk_text_buffer_get_end_iter(buffer, @iter_end);
  texto := gtk_text_buffer_get_text(buffer, @iter_start, @iter_end, FALSE);
  
  if texto <> nil then
    ObtenerTextoDeTextView := String(texto)
  else
    ObtenerTextoDeTextView := '';
  
  g_free(texto);
end;

procedure LimpiarTextView(textview: PGtkWidget);
var
  buffer: PGtkTextBuffer;
begin
  buffer := gtk_text_view_get_buffer(GTK_TEXT_VIEW(textview));
  gtk_text_buffer_set_text(buffer, '', 0);
end;

procedure MostrarDialogoInfo(const mensaje: String);
var
  dialog: PGtkWidget;
begin
  dialog := gtk_message_dialog_new(
    GTK_WINDOW(ventanaComunidades),
    GTK_DIALOG_DESTROY_WITH_PARENT,
    GTK_MESSAGE_INFO,
    GTK_BUTTONS_OK,
    PChar(mensaje)
  );
  
  gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);
end;

procedure MostrarDialogoError(const mensaje: String);
var
  dialog: PGtkWidget;
begin
  dialog := gtk_message_dialog_new(
    GTK_WINDOW(ventanaComunidades),
    GTK_DIALOG_DESTROY_WITH_PARENT,
    GTK_MESSAGE_ERROR,
    GTK_BUTTONS_OK,
    PChar(mensaje)
  );
  
  gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);
end;

procedure CrearComunidad(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombreComunidad: String;
  exito: Boolean;
begin
  // Obtener el texto del campo nombre
  nombreComunidad := Trim(ObtenerTextoDeTextView(txtNombre));
  
  // Validar que no esté vacío
  if nombreComunidad = '' then
  begin
    MostrarDialogoError('Error: El nombre de la comunidad no puede estar vacío.');
    Exit;
  end;
  
  // Crear la comunidad usando la función de la estructura
  exito := comunidades.CrearComunidad(ComunidadesGlobal, nombreComunidad);
  
  if exito then
  begin
    MostrarDialogoInfo('✅ Comunidad "' + nombreComunidad + '" creada exitosamente.');
    LimpiarTextView(txtNombre);
  end
  else
  begin
    MostrarDialogoError('❌ Error: No se pudo crear la comunidad. Verifique que no exista una comunidad con ese nombre.');
  end;
end;

procedure AgregarAComunidad(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombreComunidad, correoUsuario: String;
  usuario: PUsuario;
  exito: Boolean;
begin
  // Obtener los textos de los campos
  nombreComunidad := Trim(ObtenerTextoDeTextView(txtComunidad));
  correoUsuario := Trim(ObtenerTextoDeTextView(txtCorreo));
  
  // Validar que no estén vacíos
  if nombreComunidad = '' then
  begin
    MostrarDialogoError('Error: El nombre de la comunidad no puede estar vacío.');
    Exit;
  end;
  
  if correoUsuario = '' then
  begin
    MostrarDialogoError('Error: El correo del usuario no puede estar vacío.');
    Exit;
  end;
  
  // Buscar el usuario en la lista global
  usuario := BuscarUsuarioPorEmail(UsuariosGlobal, correoUsuario);
  
  if usuario = nil then
  begin
    MostrarDialogoError('❌ Error: No se encontró un usuario con el correo "' + correoUsuario + '".' + #10 + 
                       'El usuario debe haber sido creado previamente por el root.');
    Exit;
  end;
  
  // Agregar el usuario a la comunidad
  exito := comunidades.AgregarUsuarioAComunidad(ComunidadesGlobal, nombreComunidad, usuario);
  
  if exito then
  begin
    MostrarDialogoInfo('✅ Usuario "' + correoUsuario + '" agregado exitosamente a la comunidad "' + nombreComunidad + '".');
    LimpiarTextView(txtComunidad);
    LimpiarTextView(txtCorreo);
  end
  else
  begin
    MostrarDialogoError('❌ Error: No se pudo agregar el usuario a la comunidad.' + #10 + 
                       'Verifique que la comunidad exista y que el usuario no esté ya en ella.');
  end;
end;

procedure OnMostrarListaClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('');
  WriteLn('🔍 === LISTADO DE COMUNIDADES ===');
  comunidades.MostrarComunidades(ComunidadesGlobal);
  WriteLn('===================================');
  WriteLn('');
end;

procedure MostrarComunidades;
var
  vbox, hbox1, hbox2, hbox3, hboxButtons: PGtkWidget;
  lblComunidades, lblNombre, lblComunidad, lblCorreo: PGtkWidget;
  btnCrear, btnAgregar, btnMostrarLista: PGtkWidget;
  scrolled1, scrolled2, scrolled3: PGtkWidget;
begin
  // Crear ventana principal
  ventanaComunidades := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(ventanaComunidades), 'Gestión de Comunidades - Root');
  gtk_window_set_default_size(GTK_WINDOW(ventanaComunidades), 600, 700);
  gtk_window_set_position(GTK_WINDOW(ventanaComunidades), GTK_WIN_POS_CENTER);

  // Crear contenedor principal
  vbox := gtk_vbox_new(FALSE, 15);
  gtk_container_add(GTK_CONTAINER(ventanaComunidades), vbox);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);

  // Título principal
  lblComunidades := gtk_label_new('🏢 Gestión de Comunidades');
  gtk_label_set_markup(GTK_LABEL(lblComunidades), '<span size="x-large" weight="bold">🏢 Gestión de Comunidades</span>');
  gtk_box_pack_start(GTK_BOX(vbox), lblComunidades, FALSE, FALSE, 10);

  // === SECCIÓN CREAR COMUNIDAD ===
  // Separador visual
  gtk_box_pack_start(GTK_BOX(vbox), gtk_hseparator_new(), FALSE, FALSE, 5);
  
  // Sección Nombre para crear comunidad
  hbox1 := gtk_hbox_new(FALSE, 10);
  gtk_box_pack_start(GTK_BOX(vbox), hbox1, FALSE, FALSE, 5);
  
  lblNombre := gtk_label_new('Nombre de la comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblNombre), 0, 0.5);
  gtk_widget_set_size_request(lblNombre, 180, -1);
  gtk_box_pack_start(GTK_BOX(hbox1), lblNombre, FALSE, FALSE, 0);
  
  scrolled1 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled1), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolled1, 350, 80);
  
  txtNombre := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(txtNombre), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolled1), txtNombre);
  gtk_box_pack_start(GTK_BOX(hbox1), scrolled1, TRUE, TRUE, 0);

  // Botón Crear
  btnCrear := gtk_button_new_with_label('🆕 Crear Comunidad');
  gtk_widget_set_size_request(btnCrear, 200, 40);
  gtk_box_pack_start(GTK_BOX(vbox), btnCrear, FALSE, FALSE, 10);
  g_signal_connect(G_OBJECT(btnCrear), 'clicked', G_CALLBACK(@CrearComunidad), nil);

  // === SECCIÓN AGREGAR USUARIO ===
  // Separador visual
  gtk_box_pack_start(GTK_BOX(vbox), gtk_hseparator_new(), FALSE, FALSE, 15);

  // Sección Comunidad
  hbox2 := gtk_hbox_new(FALSE, 10);
  gtk_box_pack_start(GTK_BOX(vbox), hbox2, FALSE, FALSE, 5);
  
  lblComunidad := gtk_label_new('Nombre de comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblComunidad), 0, 0.5);
  gtk_widget_set_size_request(lblComunidad, 180, -1);
  gtk_box_pack_start(GTK_BOX(hbox2), lblComunidad, FALSE, FALSE, 0);
  
  scrolled2 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled2), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolled2, 350, 80);
  
  txtComunidad := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(txtComunidad), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolled2), txtComunidad);
  gtk_box_pack_start(GTK_BOX(hbox2), scrolled2, TRUE, TRUE, 0);

  // Sección Correo
  hbox3 := gtk_hbox_new(FALSE, 10);
  gtk_box_pack_start(GTK_BOX(vbox), hbox3, FALSE, FALSE, 5);
  
  lblCorreo := gtk_label_new('Correo del usuario:');
  gtk_misc_set_alignment(GTK_MISC(lblCorreo), 0, 0.5);
  gtk_widget_set_size_request(lblCorreo, 180, -1);
  gtk_box_pack_start(GTK_BOX(hbox3), lblCorreo, FALSE, FALSE, 0);
  
  scrolled3 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled3), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolled3, 350, 80);
  
  txtCorreo := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(txtCorreo), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolled3), txtCorreo);
  gtk_box_pack_start(GTK_BOX(hbox3), scrolled3, TRUE, TRUE, 0);

  // Botones finales
  hboxButtons := gtk_hbox_new(TRUE, 10);
  gtk_box_pack_start(GTK_BOX(vbox), hboxButtons, FALSE, FALSE, 15);

  btnAgregar := gtk_button_new_with_label('👤 Agregar Usuario');
  gtk_widget_set_size_request(btnAgregar, 180, 40);
  gtk_box_pack_start(GTK_BOX(hboxButtons), btnAgregar, TRUE, TRUE, 0);
  g_signal_connect(G_OBJECT(btnAgregar), 'clicked', G_CALLBACK(@AgregarAComunidad), nil);

  btnMostrarLista := gtk_button_new_with_label('📋 Ver Comunidades');
  gtk_widget_set_size_request(btnMostrarLista, 180, 40);
  gtk_box_pack_start(GTK_BOX(hboxButtons), btnMostrarLista, TRUE, TRUE, 0);
  g_signal_connect(G_OBJECT(btnMostrarLista), 'clicked', G_CALLBACK(@OnMostrarListaClicked), nil);

  // Mostrar todos los widgets
  gtk_widget_show_all(ventanaComunidades);
end;

end.
