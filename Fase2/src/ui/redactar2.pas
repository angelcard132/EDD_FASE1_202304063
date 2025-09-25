unit redactar2;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader;

procedure MostrarRedactarCorreo(const emailRemitente: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);

implementation

var
  GEmailRemitente: String;
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;

  RedactarWindow: PGtkWidget = nil;
  EntryPara: PGtkWidget = nil;
  EntryAsunto: PGtkWidget = nil;
  TextViewMensaje: PGtkWidget = nil;

function GenerarNuevoIDCorreo(): Integer;
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

function ObtenerTextoTextView(textView: PGtkWidget): String;
var
  buffer: PGtkTextBuffer;
  startIter, endIter: TGtkTextIter;
  texto: PChar;
begin
  buffer := gtk_text_view_get_buffer(PGtkTextView(textView));
  gtk_text_buffer_get_start_iter(buffer, @startIter);
  gtk_text_buffer_get_end_iter(buffer, @endIter);
  texto := gtk_text_buffer_get_text(buffer, @startIter, @endIter, False);
  Result := StrPas(texto);
  g_free(texto);
end;

procedure OnEnviarCorreo(widget: PGtkWidget; data: gpointer); cdecl;
var
  para, asunto, mensaje: String;
  nuevoID: Integer;
begin
  para := StrPas(gtk_entry_get_text(PGtkEntry(EntryPara)));
  asunto := StrPas(gtk_entry_get_text(PGtkEntry(EntryAsunto)));
  mensaje := ObtenerTextoTextView(TextViewMensaje);

  // Validaciones
  if (para = '') or (asunto = '') or (mensaje = '') then
  begin
    MostrarMensaje('Error de Validación', 'Todos los campos son obligatorios.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  if Pos('@', para) = 0 then
  begin
    MostrarMensaje('Error de Validación', 'El email del destinatario debe contener @.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Generar ID y enviar SOLO a Cola
  nuevoID := GenerarNuevoIDCorreo();
  Encolar(GProgramados^, nuevoID, GEmailRemitente, para, asunto, mensaje);
  
  WriteLn('✅ Correo enviado exitosamente: ', asunto);
  
  MostrarMensaje('Correo Enviado', 
    'El correo ha sido enviado exitosamente.' + LineEnding + 
    'Para: ' + para + LineEnding +
    'Asunto: ' + asunto + LineEnding + LineEnding +
    'El correo aparecerá en la bandeja del destinatario.', 
    GTK_MESSAGE_INFO);
  
  // Cerrar ventana de redactar
  if Assigned(RedactarWindow) then
    gtk_widget_destroy(RedactarWindow);
end;

procedure OnCancelarRedactar(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(RedactarWindow) then
    gtk_widget_destroy(RedactarWindow);
end;

function OnDeleteEventRedactar(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando redactar correo...');
  if Assigned(RedactarWindow) then
    gtk_widget_destroy(RedactarWindow);
  Result := True; // Prevenir cierre de aplicación
end;

procedure MostrarRedactarCorreo(const emailRemitente: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  vbox, form, hbox, btnBox, scrolledWindow: PGtkWidget;
  lblTitulo, lblPara, lblAsunto, lblMensaje: PGtkWidget;
  btnEnviar, btnCancelar: PGtkWidget;
begin
  // Guardar referencias globales
  GEmailRemitente := emailRemitente;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;

  // Si existe una ventana previa, destruirla
  if Assigned(RedactarWindow) then
    gtk_widget_destroy(RedactarWindow);

  RedactarWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(RedactarWindow), PChar('Redactar Correo - EDDMail'));
  gtk_window_set_default_size(GTK_WINDOW(RedactarWindow), 500, 400);
  gtk_window_set_resizable(GTK_WINDOW(RedactarWindow), True);

  // Conectar delete-event para prevenir cierre de aplicación
  g_signal_connect(RedactarWindow, 'delete-event', G_CALLBACK(@OnDeleteEventRedactar), nil);

  vbox := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);
  gtk_container_add(GTK_CONTAINER(RedactarWindow), vbox);

  lblTitulo := gtk_label_new(PChar('✉️ Nuevo Correo - De: ' + emailRemitente));
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  form := gtk_vbox_new(False, 12);
  gtk_box_pack_start(GTK_BOX(vbox), form, True, True, 0);

  // Para
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblPara := gtk_label_new('Para:');
  gtk_widget_set_size_request(lblPara, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblPara, False, False, 0);
  EntryPara := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryPara, True, True, 0);

  // Asunto
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblAsunto := gtk_label_new('Asunto:');
  gtk_widget_set_size_request(lblAsunto, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblAsunto, False, False, 0);
  EntryAsunto := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryAsunto, True, True, 0);

  // Mensaje
  lblMensaje := gtk_label_new('Mensaje:');
  gtk_box_pack_start(GTK_BOX(form), lblMensaje, False, False, 0);

  scrolledWindow := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledWindow), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolledWindow, -1, 200);
  gtk_box_pack_start(GTK_BOX(form), scrolledWindow, True, True, 0);

  TextViewMensaje := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewMensaje), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledWindow), TextViewMensaje);

  // Botones simplificados
  btnBox := gtk_hbox_new(True, 15);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnEnviar := gtk_button_new_with_label('📤 Enviar Correo');
  g_signal_connect(btnEnviar, 'clicked', G_CALLBACK(@OnEnviarCorreo), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnEnviar, True, True, 0);

  btnCancelar := gtk_button_new_with_label('❌ Cancelar');
  g_signal_connect(btnCancelar, 'clicked', G_CALLBACK(@OnCancelarRedactar), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCancelar, True, True, 0);

  gtk_widget_show_all(RedactarWindow);
end;

end.
  vbox := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);
  gtk_container_add(GTK_CONTAINER(RedactarWindow), vbox);

  lblTitulo := gtk_label_new(PChar('Nuevo Correo - De: ' + emailRemitente));
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  form := gtk_vbox_new(False, 12);
  gtk_box_pack_start(GTK_BOX(vbox), form, True, True, 0);

  // Para
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblPara := gtk_label_new('Para:');
  gtk_widget_set_size_request(lblPara, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblPara, False, False, 0);
  EntryPara := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryPara, True, True, 0);

  // Asunto
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblAsunto := gtk_label_new('Asunto:');
  gtk_widget_set_size_request(lblAsunto, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblAsunto, False, False, 0);
  EntryAsunto := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryAsunto, True, True, 0);

  // Mensaje
  lblMensaje := gtk_label_new('Mensaje:');
  gtk_box_pack_start(GTK_BOX(form), lblMensaje, False, False, 0);

  scrolledWindow := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledWindow), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolledWindow, -1, 200);
  gtk_box_pack_start(GTK_BOX(form), scrolledWindow, True, True, 0);

  TextViewMensaje := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewMensaje), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledWindow), TextViewMensaje);

  // Botones
  btnBox := gtk_hbox_new(True, 10);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnEnviar := gtk_button_new_with_label('Enviar');
  g_signal_connect(btnEnviar, 'clicked', G_CALLBACK(@OnEnviarCorreo), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnEnviar, True, True, 0);

  btnBorrador := gtk_button_new_with_label('Guardar Borrador');
  g_signal_connect(btnBorrador, 'clicked', G_CALLBACK(@OnGuardarBorrador), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnBorrador, True, True, 0);

  btnFavoritos := gtk_button_new_with_label('A Favoritos');
  g_signal_connect(btnFavoritos, 'clicked', G_CALLBACK(@OnAgregarAFavoritos), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnFavoritos, True, True, 0);

  btnCancelar := gtk_button_new_with_label('Cancelar');
  g_signal_connect(btnCancelar, 'clicked', G_CALLBACK(@OnCancelarRedactar), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCancelar, True, True, 0);

  gtk_widget_show_all(RedactarWindow);
end;

end.
