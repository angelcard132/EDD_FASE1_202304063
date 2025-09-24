unit registro_usuario;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader;

procedure MostrarRegistroUsuario(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);

implementation

var
  GUsuarios: ^TListaSimple = nil;

  RegistroWindow: PGtkWidget = nil;
  EntryNombre: PGtkWidget = nil;
  EntryUsuario: PGtkWidget = nil;
  EntryEmail: PGtkWidget = nil;
  EntryTelefono: PGtkWidget = nil;
  EntryPassword: PGtkWidget = nil;
  EntryConfirmPassword: PGtkWidget = nil;

function EmailExiste(const email: String): Boolean;
begin
  Result := False;
  // Simplificado: usar ValidarLogin para verificar si existe
  // Si ValidarLogin retorna algo diferente a False, significa que el email existe
  if GUsuarios <> nil then
  begin
    Result := ValidarLogin(email, 'dummy_password_check') or (email <> '');
    // Reset: esto es solo para verificar existencia, no para validar password
    Result := False; // Simplificar por ahora
  end;
end;

function GenerarNuevoID(): Integer;
begin
  // Generar ID simple basado en timestamp
  Result := Trunc(Now * 86400) mod 100000;
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

procedure OnRegistrar(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombre, usuario, email, telefono, password, confirmPassword: String;
  nuevoID: Integer;
begin
  // Obtener datos del formulario
  nombre := StrPas(gtk_entry_get_text(PGtkEntry(EntryNombre)));
  usuario := StrPas(gtk_entry_get_text(PGtkEntry(EntryUsuario)));
  email := StrPas(gtk_entry_get_text(PGtkEntry(EntryEmail)));
  telefono := StrPas(gtk_entry_get_text(PGtkEntry(EntryTelefono)));
  password := StrPas(gtk_entry_get_text(PGtkEntry(EntryPassword)));
  confirmPassword := StrPas(gtk_entry_get_text(PGtkEntry(EntryConfirmPassword)));

  // Validaciones
  if (nombre = '') or (usuario = '') or (email = '') or (telefono = '') or (password = '') then
  begin
    MostrarMensaje('Error de Validación', 'Todos los campos son obligatorios.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  if password <> confirmPassword then
  begin
    MostrarMensaje('Error de Validación', 'Las contraseñas no coinciden.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  if Length(password) < 6 then
  begin
    MostrarMensaje('Error de Validación', 'La contraseña debe tener al menos 6 caracteres.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  if Pos('@', email) = 0 then
  begin
    MostrarMensaje('Error de Validación', 'El email debe contener un símbolo @.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Crear nuevo usuario
  nuevoID := GenerarNuevoID();
  
  // Agregar a la lista simple
  AgregarUsuario(GUsuarios^, nuevoID, nombre, usuario, email, telefono);
  
  // Agregar credenciales para login
  RegistrarCredencialesUsuario(email, password, nombre);
  
  WriteLn('✅ Usuario registrado exitosamente: ', email);
  
  // Mostrar confirmación
  MostrarMensaje('Registro Exitoso', 
    'Usuario registrado correctamente.' + LineEnding + 
    'Ya puede iniciar sesión con sus credenciales.', 
    GTK_MESSAGE_INFO);
  
  // Cerrar ventana de registro
  if Assigned(RegistroWindow) then
    gtk_widget_destroy(RegistroWindow);
end;

procedure OnCancelarRegistro(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(RegistroWindow) then
    gtk_widget_destroy(RegistroWindow);
end;

procedure MostrarRegistroUsuario(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  vbox, form, hbox, btnBox: PGtkWidget;
  lblTitulo, lblNombre, lblUsuario, lblEmail, lblTelefono, lblPassword, lblConfirm: PGtkWidget;
  btnRegistrar, btnCancelar: PGtkWidget;
begin
  // Guardar solo la referencia que necesitamos
  GUsuarios := @usuarios;
  // Las otras estructuras se pasan por parámetro pero no las necesitamos como globales

  // Si existe una ventana previa, destruirla
  if Assigned(RegistroWindow) then
    gtk_widget_destroy(RegistroWindow);

  RegistroWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(RegistroWindow), PChar('Registro de Usuario - EDDMail'));
  gtk_window_set_default_size(GTK_WINDOW(RegistroWindow), 400, 450);
  gtk_window_set_resizable(GTK_WINDOW(RegistroWindow), False);

  vbox := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);
  gtk_container_add(GTK_CONTAINER(RegistroWindow), vbox);

  lblTitulo := gtk_label_new('Crear Nueva Cuenta');
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  form := gtk_vbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(vbox), form, True, True, 0);

  // Nombre
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblNombre := gtk_label_new('Nombre:');
  gtk_widget_set_size_request(lblNombre, 120, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblNombre, False, False, 0);
  EntryNombre := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryNombre, True, True, 0);

  // Usuario
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblUsuario := gtk_label_new('Usuario:');
  gtk_widget_set_size_request(lblUsuario, 120, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblUsuario, False, False, 0);
  EntryUsuario := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryUsuario, True, True, 0);

  // Email
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblEmail := gtk_label_new('Email:');
  gtk_widget_set_size_request(lblEmail, 120, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblEmail, False, False, 0);
  EntryEmail := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryEmail, True, True, 0);

  // Teléfono
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblTelefono := gtk_label_new('Teléfono:');
  gtk_widget_set_size_request(lblTelefono, 120, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblTelefono, False, False, 0);
  EntryTelefono := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryTelefono, True, True, 0);

  // Password
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblPassword := gtk_label_new('Contraseña:');
  gtk_widget_set_size_request(lblPassword, 120, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblPassword, False, False, 0);
  EntryPassword := gtk_entry_new();
  gtk_entry_set_visibility(PGtkEntry(EntryPassword), False);
  gtk_entry_set_invisible_char(PGtkEntry(EntryPassword), Ord('*'));
  gtk_box_pack_start(GTK_BOX(hbox), EntryPassword, True, True, 0);

  // Confirmar Password
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblConfirm := gtk_label_new('Confirmar:');
  gtk_widget_set_size_request(lblConfirm, 120, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblConfirm, False, False, 0);
  EntryConfirmPassword := gtk_entry_new();
  gtk_entry_set_visibility(PGtkEntry(EntryConfirmPassword), False);
  gtk_entry_set_invisible_char(PGtkEntry(EntryConfirmPassword), Ord('*'));
  gtk_box_pack_start(GTK_BOX(hbox), EntryConfirmPassword, True, True, 0);

  // Botones
  btnBox := gtk_hbox_new(True, 15);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnRegistrar := gtk_button_new_with_label('Registrar');
  g_signal_connect(btnRegistrar, 'clicked', G_CALLBACK(@OnRegistrar), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnRegistrar, True, True, 0);

  btnCancelar := gtk_button_new_with_label('Cancelar');
  g_signal_connect(btnCancelar, 'clicked', G_CALLBACK(@OnCancelarRegistro), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCancelar, True, True, 0);

  gtk_widget_show_all(RegistroWindow);
end;

end.
