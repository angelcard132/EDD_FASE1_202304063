unit programar_correo;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, SysUtils, DateUtils, cola, globals, lista_doble;

procedure MostrarProgramarCorreo;

implementation

var
  entryPara, entryAsunto: PGtkWidget;
  textContenido: PGtkWidget;
  spinDia, spinMes, spinAno: PGtkWidget;

// Declaraciones adelantadas
procedure MostrarVentanaCola; forward;
procedure OnVerColaClicked(widget: PGtkWidget; data: gpointer); cdecl; forward;

procedure OnVerColaClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarVentanaCola;
end;

procedure OnProgramarClicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  para, asunto, contenido, fechaProgramada: String;
  buffer: PGtkTextBuffer;
  startIter, endIter: TGtkTextIter;
  dia, mes, ano: Integer;
begin
  para := gtk_entry_get_text(GTK_ENTRY(entryPara));
  asunto := gtk_entry_get_text(GTK_ENTRY(entryAsunto));

  buffer := gtk_text_view_get_buffer(GTK_TEXT_VIEW(textContenido));
  gtk_text_buffer_get_start_iter(buffer, @startIter);
  gtk_text_buffer_get_end_iter(buffer, @endIter);
  contenido := gtk_text_buffer_get_text(buffer, @startIter, @endIter, True);

  dia := Round(gtk_spin_button_get_value(GTK_SPIN_BUTTON(spinDia)));
  mes := Round(gtk_spin_button_get_value(GTK_SPIN_BUTTON(spinMes)));
  ano := Round(gtk_spin_button_get_value(GTK_SPIN_BUTTON(spinAno)));

  if (Trim(para) = '') or (Trim(asunto) = '') or (Trim(contenido) = '') then
  begin
    WriteLn('⚠️ Todos los campos son obligatorios');
    Exit;
  end;

  // Validar fecha
  if (dia < 1) or (dia > 31) or (mes < 1) or (mes > 12) or (ano < 2024) then
  begin
    WriteLn('⚠️ Fecha inválida');
    Exit;
  end;

  fechaProgramada := Format('%02d/%02d/%d', [dia, mes, ano]);

  // Encolar el correo programado en la cola del usuario actual
  Encolar(ColaProgramadosUsuarioActivo,
    Random(1000000),         // ID aleatorio
    UsuarioActivo.email,     // remitente
    para,                    // destinatario
    asunto,                  // asunto
    fechaProgramada,         // fecha programada
    contenido                // mensaje
  );

  WriteLn('✅ Correo programado para el ', fechaProgramada);
  WriteLn('   De: ', UsuarioActivo.email, ' Para: ', para);

  // Limpiar campos
  gtk_entry_set_text(GTK_ENTRY(entryPara), '');
  gtk_entry_set_text(GTK_ENTRY(entryAsunto), '');
  gtk_text_buffer_set_text(buffer, '', -1);
end;

procedure MostrarDetalleCorreoProgramado(correoCola: PCorreoCola);
var
  window, vbox, labelInfo, textView, scroll: PGtkWidget;
  buffer: PGtkTextBuffer;
  detalle: String;
begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Detalle del Correo Programado');
  gtk_window_set_default_size(GTK_WINDOW(window), 450, 350);
  gtk_window_set_modal(GTK_WINDOW(window), TRUE);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  detalle :=
    'De: ' + correoCola^.remitente + LineEnding +
    'Para: ' + correoCola^.destinatario + LineEnding +
    'Asunto: ' + correoCola^.asunto + LineEnding +
    'Fecha Programada: ' + correoCola^.fecha + LineEnding +
    'Estado: PROGRAMADO';

  labelInfo := gtk_label_new(PChar(detalle));
  gtk_label_set_selectable(GTK_LABEL(labelInfo), True);
  gtk_box_pack_start(GTK_BOX(vbox), labelInfo, FALSE, FALSE, 5);

  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 5);

  textView := gtk_text_view_new;
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(textView), GTK_WRAP_WORD);
  gtk_text_view_set_editable(GTK_TEXT_VIEW(textView), FALSE);
  buffer := gtk_text_view_get_buffer(GTK_TEXT_VIEW(textView));
  
  if correoCola^.mensaje <> '' then
    gtk_text_buffer_set_text(buffer, PChar(correoCola^.mensaje), -1)
  else
    gtk_text_buffer_set_text(buffer, PChar('(Sin contenido)'), -1);
    
  gtk_container_add(GTK_CONTAINER(scroll), textView);

  gtk_widget_show_all(window);
end;

procedure OnRowActivatedCola(treeview: PGtkTreeView; path: PGtkTreePath; column: PGtkTreeViewColumn; user_data: gpointer); cdecl;
var
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  pId: Pgchar = nil;
  sId: String;
  idCorreo: Integer;
  aux: PCorreoCola;
begin
  model := gtk_tree_view_get_model(treeview);
  if gtk_tree_model_get_iter(model, @iter, path) then
  begin
    try
      gtk_tree_model_get(model, @iter, 0, @pId, -1);
      if pId <> nil then sId := StrPas(pId);
      
      if TryStrToInt(sId, idCorreo) then
      begin
        // Buscar el correo en la cola por ID
        aux := ColaProgramadosUsuarioActivo.frente;
        while aux <> nil do
        begin
          if aux^.id = idCorreo then
          begin
            MostrarDetalleCorreoProgramado(aux);
            Break;
          end;
          aux := aux^.siguiente;
        end;
      end;
    finally
      if pId <> nil then g_free(pId);
    end;
  end;
end;

procedure MostrarVentanaCola;
var
  window, vbox, scroll, treeview, lblUsuario, hboxBotones, btnEnviar: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  iter: TGtkTreeIter;
  aux: PCorreoCola;
  tituloUsuario: String;
  correosProgramados: Integer;
  
  procedure OnEnviarTodosClicked(widget: PGtkWidget; data: gpointer); cdecl;
  var
    aux: PCorreoCola;
    fechaActual: String;
    correosEnviados: Integer;
  begin
    fechaActual := DateToStr(Date);
    correosEnviados := 0;
    
    WriteLn('📤 Enviando todos los correos programados...');
    
    // Procesar todos los correos de la cola
    while ColaProgramadosUsuarioActivo.frente <> nil do
    begin
      aux := Desencolar(ColaProgramadosUsuarioActivo);
      if aux <> nil then
      begin
        // Insertar en la lista global de correos como enviado
        lista_doble.InsertarCorreo(CorreosGlobal,
          aux^.id,
          aux^.remitente,
          aux^.destinatario,
          'NL',                // Estado no leído para el destinatario
          aux^.asunto,
          fechaActual,         // Fecha actual de envío
          aux^.mensaje
        );
        
        WriteLn('  ✅ Enviado: ', aux^.asunto, ' a ', aux^.destinatario);
        Inc(correosEnviados);
        
        // Liberar memoria del nodo de la cola
        Dispose(aux);
      end;
    end;
    
    WriteLn('📊 Total correos enviados: ', correosEnviados);
    
    // Actualizar la tabla (limpiarla)
    store := gtk_list_store_new(5, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
    gtk_tree_view_set_model(GTK_TREE_VIEW(treeview), GTK_TREE_MODEL(store));
    
    WriteLn('✅ Todos los correos programados han sido enviados');
  end;

begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Cola de Correos Programados');
  gtk_window_set_default_size(GTK_WINDOW(window), 700, 450);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Mostrar a qué usuario pertenecen los correos programados
  tituloUsuario := 'Correos programados de: ' + UsuarioActivo.email;
  lblUsuario := gtk_label_new(PChar('<b>' + tituloUsuario + '</b>'));
  gtk_label_set_use_markup(GTK_LABEL(lblUsuario), TRUE);
  gtk_box_pack_start(GTK_BOX(vbox), lblUsuario, FALSE, FALSE, 5);

  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 0);

  // 5 columnas: ID | Para | Asunto | Fecha | Mensaje
  store := gtk_list_store_new(5, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  treeview := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('ID', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 60);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Para', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 200);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Fecha Programada', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 120);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Mensaje', renderer, 'text', 4, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  gtk_container_add(GTK_CONTAINER(scroll), treeview);

  // Botones
  hboxBotones := gtk_hbox_new(FALSE, 10);
  gtk_box_pack_start(GTK_BOX(vbox), hboxBotones, FALSE, FALSE, 5);

  btnEnviar := gtk_button_new_with_label('📤 Enviar Todos los Correos');
  g_signal_connect(btnEnviar, 'clicked', G_CALLBACK(@OnEnviarTodosClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBotones), btnEnviar, FALSE, FALSE, 5);

  // Llenar la tabla con los correos de la cola del usuario actual
  correosProgramados := 0;
  aux := ColaProgramadosUsuarioActivo.frente;
  while aux <> nil do
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
      0, PChar(IntToStr(aux^.id)),
      1, PChar(aux^.destinatario),
      2, PChar(aux^.asunto),
      3, PChar(aux^.fecha),
      4, PChar(aux^.mensaje),
      -1);
    aux := aux^.siguiente;
    Inc(correosProgramados);
  end;

  WriteLn('📧 Correos programados para ', UsuarioActivo.email, ': ', correosProgramados);

  // Doble clic en una fila → abre detalle
  g_signal_connect(treeview, 'row-activated', G_CALLBACK(@OnRowActivatedCola), nil);

  gtk_widget_show_all(window);
end;

procedure MostrarProgramarCorreo;
var
  window, vbox, hbox, lbl: PGtkWidget;
  scroll, btnProgramar, btnVerCola: PGtkWidget;
  hboxFecha, hboxBotones: PGtkWidget;
  adjustment: PGtkAdjustment;
  fechaActual: TDateTime;
  diaActual, mesActual, anoActual: Word;
  tituloUsuario: String;
begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Programar Correo');
  gtk_window_set_default_size(GTK_WINDOW(window), 500, 450);

  vbox := gtk_vbox_new(FALSE, 8);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Título con usuario actual
  tituloUsuario := 'Programar Correo para: ' + UsuarioActivo.email;
  lbl := gtk_label_new(PChar('<b>' + tituloUsuario + '</b>'));
  gtk_label_set_use_markup(GTK_LABEL(lbl), TRUE);
  gtk_box_pack_start(GTK_BOX(vbox), lbl, FALSE, FALSE, 5);

  // Para:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Para:');
  gtk_widget_set_size_request(lbl, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryPara := gtk_entry_new;
  gtk_box_pack_start(GTK_BOX(hbox), entryPara, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Asunto:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Asunto:');
  gtk_widget_set_size_request(lbl, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryAsunto := gtk_entry_new;
  gtk_box_pack_start(GTK_BOX(hbox), entryAsunto, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Fecha programada
  lbl := gtk_label_new('<b>Fecha de Envío:</b>');
  gtk_label_set_use_markup(GTK_LABEL(lbl), TRUE);
  gtk_box_pack_start(GTK_BOX(vbox), lbl, FALSE, FALSE, 5);

  // Obtener fecha actual
  fechaActual := Now;
  DecodeDate(fechaActual, anoActual, mesActual, diaActual);

  // Fila de fecha
  hboxFecha := gtk_hbox_new(FALSE, 10);
  
  lbl := gtk_label_new('Día:');
  gtk_box_pack_start(GTK_BOX(hboxFecha), lbl, FALSE, FALSE, 5);
  adjustment := PGtkAdjustment(gtk_adjustment_new(diaActual, 1, 31, 1, 1, 0));
  spinDia := gtk_spin_button_new(adjustment, 1, 0);
  gtk_box_pack_start(GTK_BOX(hboxFecha), spinDia, FALSE, FALSE, 5);

  lbl := gtk_label_new('Mes:');
  gtk_box_pack_start(GTK_BOX(hboxFecha), lbl, FALSE, FALSE, 5);
  adjustment := PGtkAdjustment(gtk_adjustment_new(mesActual, 1, 12, 1, 1, 0));
  spinMes := gtk_spin_button_new(adjustment, 1, 0);
  gtk_box_pack_start(GTK_BOX(hboxFecha), spinMes, FALSE, FALSE, 5);

  lbl := gtk_label_new('Año:');
  gtk_box_pack_start(GTK_BOX(hboxFecha), lbl, FALSE, FALSE, 5);
  adjustment := PGtkAdjustment(gtk_adjustment_new(anoActual, 2024, 2030, 1, 1, 0));
  spinAno := gtk_spin_button_new(adjustment, 1, 0);
  gtk_box_pack_start(GTK_BOX(hboxFecha), spinAno, FALSE, FALSE, 5);

  gtk_box_pack_start(GTK_BOX(vbox), hboxFecha, FALSE, FALSE, 5);

  // Contenido:
  lbl := gtk_label_new('Contenido:');
  gtk_box_pack_start(GTK_BOX(vbox), lbl, FALSE, FALSE, 5);
  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 5);

  textContenido := gtk_text_view_new;
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(textContenido), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scroll), textContenido);

  // Botones
  hboxBotones := gtk_hbox_new(TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hboxBotones, FALSE, FALSE, 5);

  btnProgramar := gtk_button_new_with_label('⏰ Programar Envío');
  g_signal_connect(btnProgramar, 'clicked', G_CALLBACK(@OnProgramarClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBotones), btnProgramar, TRUE, TRUE, 5);

  btnVerCola := gtk_button_new_with_label('📋 Ver Cola');
  g_signal_connect(btnVerCola, 'clicked', G_CALLBACK(@OnVerColaClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBotones), btnVerCola, TRUE, TRUE, 5);

  gtk_widget_show_all(window);
end;

end.