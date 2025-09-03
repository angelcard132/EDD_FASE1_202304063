unit papelera;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, SysUtils, pila, globals;

procedure MostrarPapelera;

implementation

procedure MostrarDetalleCorreoPapelera(correoPila: PCorreoPila);
var
  window, vbox, labelInfo, textView, scroll: PGtkWidget;
  buffer: PGtkTextBuffer;
  detalle: String;
begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Detalle del Correo (Papelera)');
  gtk_window_set_default_size(GTK_WINDOW(window), 450, 350);
  gtk_window_set_modal(GTK_WINDOW(window), TRUE);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  detalle :=
    'De: ' + correoPila^.remitente + LineEnding +
    'Asunto: ' + correoPila^.asunto + LineEnding +
    'Fecha: ' + correoPila^.fecha + LineEnding +
    'Estado: EN PAPELERA';

  labelInfo := gtk_label_new(PChar(detalle));
  gtk_label_set_selectable(GTK_LABEL(labelInfo), True);
  gtk_box_pack_start(GTK_BOX(vbox), labelInfo, FALSE, FALSE, 5);

  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 5);

  textView := gtk_text_view_new;
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(textView), GTK_WRAP_WORD);
  gtk_text_view_set_editable(GTK_TEXT_VIEW(textView), FALSE);
  buffer := gtk_text_view_get_buffer(GTK_TEXT_VIEW(textView));
  
  if correoPila^.mensaje <> '' then
    gtk_text_buffer_set_text(buffer, PChar(correoPila^.mensaje), -1)
  else
    gtk_text_buffer_set_text(buffer, PChar('(Sin contenido)'), -1);
    
  gtk_container_add(GTK_CONTAINER(scroll), textView);

  gtk_widget_show_all(window);
end;

procedure OnRowActivated(treeview: PGtkTreeView; path: PGtkTreePath; column: PGtkTreeViewColumn; user_data: gpointer); cdecl;
var
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  pId: Pgchar = nil;
  sId: String;
  idCorreo: Integer;
  aux: PCorreoPila;
begin
  model := gtk_tree_view_get_model(treeview);
  if gtk_tree_model_get_iter(model, @iter, path) then
  begin
    try
      gtk_tree_model_get(model, @iter, 0, @pId, -1);
      if pId <> nil then sId := StrPas(pId);
      
      if TryStrToInt(sId, idCorreo) then
      begin
        // Buscar el correo en la pila por ID
        aux := PapeleraUsuarioActivo.tope;
        while aux <> nil do
        begin
          if aux^.id = idCorreo then
          begin
            MostrarDetalleCorreoPapelera(aux);
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

procedure MostrarPapelera;
var
  window, vbox, scroll, treeview, lblUsuario, hboxBotones, btnVaciar, btnActualizar: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  iter: TGtkTreeIter;
  aux: PCorreoPila;
  tituloUsuario: String;
  correosPapelera: Integer;
  
  procedure ActualizarTabla;
  begin
    // Limpiar tabla actual
    gtk_list_store_clear(store);
    
    // Llenar la tabla con correos de la pila (LIFO - último eliminado arriba)
    correosPapelera := 0;
    aux := PapeleraUsuarioActivo.tope;
    while aux <> nil do
    begin
      gtk_list_store_append(store, @iter);
      gtk_list_store_set(store, @iter,
        0, PChar(IntToStr(aux^.id)),
        1, PChar(aux^.remitente),
        2, PChar(aux^.asunto),
        3, PChar(aux^.fecha),
        -1);
      aux := aux^.siguiente;
      Inc(correosPapelera);
    end;
    
    WriteLn('🗑️ Papelera actualizada: ', correosPapelera, ' correos para ', UsuarioActivo.email);
  end;
  
  procedure OnVaciarPapeleraClicked(widget: PGtkWidget; data: gpointer); cdecl;
  var
    aux: PCorreoPila;
    eliminados: Integer;
  begin
    eliminados := 0;
    
    WriteLn('🗑️ Vaciando papelera...');
    
    // Vaciar completamente la pila
    while PapeleraUsuarioActivo.tope <> nil do
    begin
      aux := Pop(PapeleraUsuarioActivo);
      if aux <> nil then
      begin
        WriteLn('  🗑️ Eliminado permanentemente: ', aux^.asunto);
        Inc(eliminados);
        Dispose(aux);
      end;
    end;
    
    WriteLn('📊 Total correos eliminados permanentemente: ', eliminados);
    
    // Actualizar la interfaz limpiando la tabla
    ActualizarTabla;
    
    WriteLn('✅ Papelera vaciada completamente');
  end;
  
  procedure OnActualizarClicked(widget: PGtkWidget; data: gpointer); cdecl;
  begin
    WriteLn('🔄 Actualizando vista de papelera...');
    ActualizarTabla;
  end;

begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Papelera (Pila LIFO)');
  gtk_window_set_default_size(GTK_WINDOW(window), 650, 400);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Mostrar a qué usuario pertenece la papelera
  tituloUsuario := 'Papelera de: ' + UsuarioActivo.email + ' (Estructura: Pila LIFO)';
  lblUsuario := gtk_label_new(PChar('<b>' + tituloUsuario + '</b>'));
  gtk_label_set_use_markup(GTK_LABEL(lblUsuario), TRUE);
  gtk_box_pack_start(GTK_BOX(vbox), lblUsuario, FALSE, FALSE, 5);

  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 0);

  // 4 columnas: ID | Remitente | Asunto | Fecha
  store := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  treeview := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('ID', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 80);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Remitente', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 200);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Fecha', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 100);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  gtk_container_add(GTK_CONTAINER(scroll), treeview);

  // Botones
  hboxBotones := gtk_hbox_new(FALSE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hboxBotones, FALSE, FALSE, 5);

  btnActualizar := gtk_button_new_with_label('🔄 Actualizar');
  g_signal_connect(btnActualizar, 'clicked', G_CALLBACK(@OnActualizarClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBotones), btnActualizar, FALSE, FALSE, 5);

  btnVaciar := gtk_button_new_with_label('🗑️ Vaciar Papelera');
  g_signal_connect(btnVaciar, 'clicked', G_CALLBACK(@OnVaciarPapeleraClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBotones), btnVaciar, FALSE, FALSE, 5);

  // Cargar correos iniciales en la tabla
  ActualizarTabla;

  // Doble clic en una fila → abre detalle
  g_signal_connect(treeview, 'row-activated', G_CALLBACK(@OnRowActivated), nil);

  gtk_widget_show_all(window);
end;

end.
  aux := CorreosGlobal.primero;
  while aux <> nil do
  begin
    // Mostrar correos eliminados que involucren al usuario actual (enviados o recibidos)
    if (aux^.estado = 'DEL') and 
       ((LowerCase(aux^.destinatario) = LowerCase(UsuarioActivo.email)) or 
        (LowerCase(aux^.remitente) = LowerCase(UsuarioActivo.email))) then
    begin
      gtk_list_store_append(store, @iter);
      gtk_list_store_set(store, @iter,
        0, PChar(LimpiarUTF8Papelera(aux^.remitente)),
        1, PChar(LimpiarUTF8Papelera(aux^.asunto)),
        2, PChar(LimpiarUTF8Papelera(aux^.fecha)),
        3, PChar('ELIMINADO'),
        -1);
      Inc(correosPapelera);
    end;
    aux := aux^.siguiente;
  end;

  WriteLn('📧 Correos en papelera para ', UsuarioActivo.email, ': ', correosPapelera);

  g_signal_connect(treeview, 'row-activated', G_CALLBACK(@OnRowActivated), nil);

  gtk_widget_show_all(window);
end;

end.
