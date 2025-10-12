unit perfil;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader;

procedure MostrarPerfil(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);

implementation

var
  GEmailUsuario: String;
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  
  PerfilWindow: PGtkWidget = nil;
  EditarWindow: PGtkWidget = nil;
  
  // Datos del usuario actual
  GUsuarioActual: PUsuario = nil;

{ === FUNCIONES AUXILIARES === }

function BuscarUsuarioPorEmail(const email: String; lista: TListaSimple): PUsuario;
var
  actual: PUsuario;
begin
  Result := nil;
  actual := lista.cabeza;
  while actual <> nil do
  begin
    if LowerCase(String(actual^.email)) = LowerCase(email) then
    begin
      Result := actual;
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

procedure MostrarMensaje(const titulo, mensaje: String; tipoMensaje: TGtkMessageType);
var
  dialog: PGtkWidget;
begin
  dialog := gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, tipoMensaje, GTK_BUTTONS_OK, PChar(mensaje));
  gtk_window_set_title(GTK_WINDOW(dialog), PChar(titulo));
  gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);
end;

{ === FORMULARIO EDITAR PERFIL === }

var
  EntryNombre: PGtkWidget = nil;
  EntryUsuario: PGtkWidget = nil;
  EntryTelefono: PGtkWidget = nil;
  EntryPassword: PGtkWidget = nil;

procedure OnGuardarCambios(widget: PGtkWidget; data: gpointer); cdecl;
var
  nuevoNombre, nuevoUsuario, nuevoTelefono, nuevoPassword: String;
begin
  if GUsuarioActual = nil then
  begin
    MostrarMensaje('Error', 'No se encontró el usuario actual.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  nuevoNombre := StrPas(gtk_entry_get_text(PGtkEntry(EntryNombre)));
  nuevoUsuario := StrPas(gtk_entry_get_text(PGtkEntry(EntryUsuario)));
  nuevoTelefono := StrPas(gtk_entry_get_text(PGtkEntry(EntryTelefono)));
  nuevoPassword := StrPas(gtk_entry_get_text(PGtkEntry(EntryPassword)));

  // Validaciones
  if (nuevoNombre = '') or (nuevoUsuario = '') or (nuevoTelefono = '') then
  begin
    MostrarMensaje('Error de Validación', 'Los campos Nombre, Usuario y Teléfono son obligatorios.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Actualizar datos en la lista simple
  GUsuarioActual^.nombre := nuevoNombre;
  GUsuarioActual^.usuario := nuevoUsuario;
  GUsuarioActual^.telefono := nuevoTelefono;

  // Actualizar password si se proporcionó uno nuevo
  if nuevoPassword <> '' then
  begin
    RegistrarCredencialesUsuario(String(GUsuarioActual^.email), nuevoPassword, nuevoNombre);
    WriteLn('✅ Password actualizado para: ', String(GUsuarioActual^.email));
  end;

  WriteLn('✅ Perfil actualizado: ', nuevoNombre, ' (', String(GUsuarioActual^.email), ')');

  MostrarMensaje('Perfil Actualizado', 
    'Los datos han sido actualizados exitosamente.' + LineEnding + 
    'Nombre: ' + nuevoNombre + LineEnding +
    'Usuario: ' + nuevoUsuario + LineEnding +
    'Teléfono: ' + nuevoTelefono + LineEnding +
    'Email: ' + String(GUsuarioActual^.email), 
    GTK_MESSAGE_INFO);

  // Cerrar ventana de edición
  if Assigned(EditarWindow) then
    gtk_widget_destroy(EditarWindow);
end;

procedure OnCancelarEdicion(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(EditarWindow) then
    gtk_widget_destroy(EditarWindow);
end;

function OnDeleteEventEditar(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando edición perfil...');
  if Assigned(EditarWindow) then
    gtk_widget_destroy(EditarWindow);
  Result := True;
end;

procedure MostrarFormularioEditar();
var
  vbox, form, hbox, btnBox: PGtkWidget;
  lblTitulo, lblNombre, lblUsuario, lblTelefono, lblPassword, lblEmail: PGtkWidget;
  btnGuardar, btnCancelar: PGtkWidget;
  entryEmail: PGtkWidget;
begin
  if GUsuarioActual = nil then
  begin
    MostrarMensaje('Error', 'No se encontró el usuario actual.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  if Assigned(EditarWindow) then
    gtk_widget_destroy(EditarWindow);

  EditarWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(EditarWindow), PChar('✏️ Editar Perfil - EDDMail'));
  gtk_window_set_default_size(GTK_WINDOW(EditarWindow), 450, 400);
  gtk_window_set_position(GTK_WINDOW(EditarWindow), GTK_WIN_POS_CENTER);

  g_signal_connect(EditarWindow, 'delete-event', G_CALLBACK(@OnDeleteEventEditar), nil);

  vbox := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);
  gtk_container_add(GTK_CONTAINER(EditarWindow), vbox);

  lblTitulo := gtk_label_new(PChar('✏️ Editar Datos del Perfil'));
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  form := gtk_vbox_new(False, 12);
  gtk_box_pack_start(GTK_BOX(vbox), form, True, True, 0);

  // Nombre
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblNombre := gtk_label_new('Nombre:');
  gtk_widget_set_size_request(lblNombre, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblNombre, False, False, 0);
  EntryNombre := gtk_entry_new();
  gtk_entry_set_text(PGtkEntry(EntryNombre), PChar(String(GUsuarioActual^.nombre)));
  gtk_box_pack_start(GTK_BOX(hbox), EntryNombre, True, True, 0);

  // Usuario
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblUsuario := gtk_label_new('Usuario:');
  gtk_widget_set_size_request(lblUsuario, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblUsuario, False, False, 0);
  EntryUsuario := gtk_entry_new();
  gtk_entry_set_text(PGtkEntry(EntryUsuario), PChar(String(GUsuarioActual^.usuario)));
  gtk_box_pack_start(GTK_BOX(hbox), EntryUsuario, True, True, 0);

  // Email (solo lectura)
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblEmail := gtk_label_new('Email:');
  gtk_widget_set_size_request(lblEmail, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblEmail, False, False, 0);
  entryEmail := gtk_entry_new();
  gtk_entry_set_text(PGtkEntry(entryEmail), PChar(String(GUsuarioActual^.email)));
  gtk_widget_set_sensitive(entryEmail, False); // Solo lectura
  gtk_box_pack_start(GTK_BOX(hbox), entryEmail, True, True, 0);

  // Teléfono
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblTelefono := gtk_label_new('Teléfono:');
  gtk_widget_set_size_request(lblTelefono, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblTelefono, False, False, 0);
  EntryTelefono := gtk_entry_new();
  gtk_entry_set_text(PGtkEntry(EntryTelefono), PChar(String(GUsuarioActual^.telefono)));
  gtk_box_pack_start(GTK_BOX(hbox), EntryTelefono, True, True, 0);

  // Password (opcional)
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblPassword := gtk_label_new('Nueva Pass:');
  gtk_widget_set_size_request(lblPassword, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblPassword, False, False, 0);
  EntryPassword := gtk_entry_new();
  gtk_entry_set_visibility(PGtkEntry(EntryPassword), False);
  gtk_entry_set_text(PGtkEntry(EntryPassword), '');
  gtk_box_pack_start(GTK_BOX(hbox), EntryPassword, True, True, 0);

  // Botones
  btnBox := gtk_hbox_new(True, 15);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnGuardar := gtk_button_new_with_label('✅ Guardar Cambios');
  g_signal_connect(btnGuardar, 'clicked', G_CALLBACK(@OnGuardarCambios), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnGuardar, True, True, 0);

  btnCancelar := gtk_button_new_with_label('❌ Cancelar');
  g_signal_connect(btnCancelar, 'clicked', G_CALLBACK(@OnCancelarEdicion), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCancelar, True, True, 0);

  gtk_widget_show_all(EditarWindow);
end;

{ === VISTA DEL PERFIL === }

procedure OnEditarPerfil(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarFormularioEditar();
end;

procedure OnCerrarPerfil(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(PerfilWindow) then
    gtk_widget_destroy(PerfilWindow);
end;

function OnDeleteEventPerfil(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando perfil...');
  if Assigned(PerfilWindow) then
    gtk_widget_destroy(PerfilWindow);
  Result := True;
end;

procedure MostrarPerfil(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  vbox, infoBox, btnBox: PGtkWidget;
  lblTitulo, lblID, lblNombre, lblUsuario, lblEmail, lblTelefono: PGtkWidget;
  btnEditar, btnCerrar: PGtkWidget;
  frame: PGtkWidget;
begin
  // Guardar referencias globales
  GEmailUsuario := emailUsuario;
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;

  // Buscar usuario actual
  GUsuarioActual := BuscarUsuarioPorEmail(emailUsuario, usuarios);
  if GUsuarioActual = nil then
  begin
    MostrarMensaje('Error', 'No se encontró el usuario en el sistema.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  if Assigned(PerfilWindow) then
    gtk_widget_destroy(PerfilWindow);

  PerfilWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(PerfilWindow), PChar('👤 Mi Perfil - EDDMail'));
  gtk_window_set_default_size(GTK_WINDOW(PerfilWindow), 450, 350);
  gtk_window_set_position(GTK_WINDOW(PerfilWindow), GTK_WIN_POS_CENTER);

  g_signal_connect(PerfilWindow, 'delete-event', G_CALLBACK(@OnDeleteEventPerfil), nil);

  vbox := gtk_vbox_new(False, 20);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 25);
  gtk_container_add(GTK_CONTAINER(PerfilWindow), vbox);

  lblTitulo := gtk_label_new(PChar('👤 Información del Perfil'));
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  // Frame para la información
  frame := gtk_frame_new('Datos Personales');
  gtk_box_pack_start(GTK_BOX(vbox), frame, True, True, 0);

  infoBox := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(infoBox), 20);
  gtk_container_add(GTK_CONTAINER(frame), infoBox);

  // Mostrar información del usuario
  lblID := gtk_label_new(PChar('🆔 ID: ' + IntToStr(GUsuarioActual^.id)));
  gtk_misc_set_alignment(GTK_MISC(lblID), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(infoBox), lblID, False, False, 0);

  lblNombre := gtk_label_new(PChar('👤 Nombre: ' + String(GUsuarioActual^.nombre)));
  gtk_misc_set_alignment(GTK_MISC(lblNombre), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(infoBox), lblNombre, False, False, 0);

  lblUsuario := gtk_label_new(PChar('🏷️ Usuario: ' + String(GUsuarioActual^.usuario)));
  gtk_misc_set_alignment(GTK_MISC(lblUsuario), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(infoBox), lblUsuario, False, False, 0);

  lblEmail := gtk_label_new(PChar('📧 Email: ' + String(GUsuarioActual^.email)));
  gtk_misc_set_alignment(GTK_MISC(lblEmail), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(infoBox), lblEmail, False, False, 0);

  lblTelefono := gtk_label_new(PChar('📞 Teléfono: ' + String(GUsuarioActual^.telefono)));
  gtk_misc_set_alignment(GTK_MISC(lblTelefono), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(infoBox), lblTelefono, False, False, 0);

  // Botones
  btnBox := gtk_hbox_new(True, 15);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnEditar := gtk_button_new_with_label('✏️ Actualizar Datos');
  gtk_widget_set_size_request(btnEditar, 150, 40);
  g_signal_connect(btnEditar, 'clicked', G_CALLBACK(@OnEditarPerfil), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnEditar, True, True, 0);

  btnCerrar := gtk_button_new_with_label('🔙 Regresar');
  gtk_widget_set_size_request(btnCerrar, 150, 40);
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarPerfil), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCerrar, True, True, 0);

  gtk_widget_show_all(PerfilWindow);
end;

end.
