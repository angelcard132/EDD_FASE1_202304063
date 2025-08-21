unit redactar;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, SysUtils, lista_doble, lista_simple, globals;

procedure MostrarRedactar;

implementation

var
  entryPara, entryAsunto: PGtkWidget;
  textContenido: PGtkWidget;

procedure OnEnviarClicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  para, asunto, contenido, fecha: String;
  buffer: PGtkTextBuffer;
  startIter, endIter: TGtkTextIter;
begin
  para   := gtk_entry_get_text(GTK_ENTRY(entryPara));
  asunto := gtk_entry_get_text(GTK_ENTRY(entryAsunto));

  buffer := gtk_text_view_get_buffer(GTK_TEXT_VIEW(textContenido));
  gtk_text_buffer_get_start_iter(buffer, @startIter);
  gtk_text_buffer_get_end_iter(buffer, @endIter);
  contenido := gtk_text_buffer_get_text(buffer, @startIter, @endIter, True);

  fecha := DateToStr(Date);

  if (Trim(para) = '') or (Trim(asunto) = '') or (Trim(contenido) = '') then
  begin
    WriteLn('⚠️ Todos los campos son obligatorios');
    Exit;
  end;

  // Asegurar lista global inicializada
  if (CorreosGlobal.primero = nil) and (CorreosGlobal.ultimo = nil) then
    InicializarListaCorreos(CorreosGlobal);

  // Insertar correo en la lista global
  InsertarCorreo(CorreosGlobal,
    Random(1000000),         // ID sencillo
    UsuarioActivo.email,     // remitente
    para,                    // destinatario
    'NL',                    // estado inicial
    asunto,                  // asunto
    fecha,                   // fecha
    contenido                // contenido
  );

  WriteLn('✅ Correo enviado de ', UsuarioActivo.email, ' a ', para);
end;

procedure MostrarRedactar;
var
  window, vbox, hbox, lbl: PGtkWidget;
  scroll, btnEnviar: PGtkWidget;
begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Redactar Correo');
  gtk_window_set_default_size(GTK_WINDOW(window), 450, 420);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Para:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Para:');
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryPara := gtk_entry_new;
  gtk_box_pack_start(GTK_BOX(hbox), entryPara, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Asunto:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Asunto:');
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryAsunto := gtk_entry_new;
  gtk_box_pack_start(GTK_BOX(hbox), entryAsunto, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Contenido:
  lbl := gtk_label_new('Contenido:');
  gtk_box_pack_start(GTK_BOX(vbox), lbl, FALSE, FALSE, 5);
  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 5);

  textContenido := gtk_text_view_new;
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(textContenido), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scroll), textContenido);

  // Enviar
  btnEnviar := gtk_button_new_with_label('Enviar');
  g_signal_connect(btnEnviar, 'clicked', G_CALLBACK(@OnEnviarClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnEnviar, FALSE, FALSE, 5);

  gtk_widget_show_all(window);
end;

end.
