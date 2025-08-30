unit bandeja;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, lista_doble, lista_simple, json_loader, SysUtils, papelera, globals, redactar, pila;

procedure MostrarBandeja(const usuario: TUsuario);

implementation

function LimpiarUTF8(const texto: String): String;
var
  i: Integer;
  resultado: String;
begin
  resultado := '';
  for i := 1 to Length(texto) do
  begin
    if Ord(texto[i]) < 128 then  // Solo caracteres ASCII seguros
      resultado := resultado + texto[i]
    else
      resultado := resultado + '?';  // Reemplazar caracteres problemáticos
  end;
  Result := resultado;
end;

procedure MostrarDetalleCorreo(correo: PCorreo);
var
  window, vbox, labelInfo, textView, scroll: PGtkWidget;
  buffer: PGtkTextBuffer;
  detalle: String;

begin
  if (correo <> nil) and (correo^.estado <> 'DEL') then
    correo^.estado := 'L';
    
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Detalle del Correo');
  gtk_window_set_default_size(GTK_WINDOW(window), 450, 350);
  gtk_window_set_modal(GTK_WINDOW(window), TRUE);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  detalle :=
    'De: ' + LimpiarUTF8(correo^.remitente) + LineEnding +
    'Para: ' + LimpiarUTF8(correo^.destinatario) + LineEnding +
    'Asunto: ' + LimpiarUTF8(correo^.asunto) + LineEnding +
    'Fecha: ' + LimpiarUTF8(correo^.fecha);

  labelInfo := gtk_label_new(PChar(detalle));
  gtk_label_set_selectable(GTK_LABEL(labelInfo), True);
  gtk_box_pack_start(GTK_BOX(vbox), labelInfo, FALSE, FALSE, 5);

  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 5);

  textView := gtk_text_view_new;
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(textView), GTK_WRAP_WORD);
  gtk_text_view_set_editable(GTK_TEXT_VIEW(textView), FALSE);
  buffer := gtk_text_view_get_buffer(GTK_TEXT_VIEW(textView));
  
  // Verificar que el contenido sea válido UTF-8
  if correo^.contenido <> '' then
    gtk_text_buffer_set_text(buffer, PChar(LimpiarUTF8(correo^.contenido)), -1)
  else
    gtk_text_buffer_set_text(buffer, PChar('(Sin contenido)'), -1);
    
  gtk_container_add(GTK_CONTAINER(scroll), textView);

  gtk_widget_show_all(window);
end;

procedure OnRowActivated(treeview: PGtkTreeView; path: PGtkTreePath; column: PGtkTreeViewColumn; user_data: gpointer); cdecl;
var
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  pRem: Pgchar = nil;
  pAsu: Pgchar = nil;
  pFec: Pgchar = nil;
  sRem, sAsu, sFec: String;
  aux: PCorreo;
begin
  model := gtk_tree_view_get_model(treeview);
  if gtk_tree_model_get_iter(model, @iter, path) then
  begin
    // Obtener strings de la fila (glib asigna memoria que debemos liberar)
    gtk_tree_model_get(model, @iter, 0, @pRem, 1, @pAsu, 2, @pFec, -1);
    
    try
      if pRem <> nil then sRem := LimpiarUTF8(StrPas(pRem));
      if pAsu <> nil then sAsu := LimpiarUTF8(StrPas(pAsu));
      if pFec <> nil then sFec := LimpiarUTF8(StrPas(pFec));

      // Buscar el correo en la lista global
      aux := CorreosGlobal.primero;
      while aux <> nil do
      begin
        if (LimpiarUTF8(aux^.remitente) = sRem) and (LimpiarUTF8(aux^.asunto) = sAsu) and (LimpiarUTF8(aux^.fecha) = sFec) then
        begin
          MostrarDetalleCorreo(aux);
          // Actualizar estado en la tabla
          gtk_list_store_set(PGtkListStore(model), @iter, 3, PChar(LimpiarUTF8(aux^.estado)), -1);
          Break;
        end;
        aux := aux^.siguiente;
      end;
    finally
      // Liberar memoria de glib
      if pRem <> nil then g_free(pRem);
      if pAsu <> nil then g_free(pAsu);
      if pFec <> nil then g_free(pFec);
    end;
  end;
end;

procedure MostrarBandeja(const usuario: TUsuario);
var
  window, vbox, hboxBotones, scroll, treeview, btnEliminar: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  iter: TGtkTreeIter;
  aux: PCorreo;
  correosEncontrados: Integer;
  
  procedure OnEliminarClicked(widget: PGtkWidget; data: gpointer); cdecl;
  var
    selection: PGtkTreeSelection;
    model: PGtkTreeModel;
    iter: TGtkTreeIter;
    path: PGtkTreePath;
    indices: PGint;
    indice: Integer;
    aux, anterior: PCorreo;
    contador: Integer;
    encontrado: Boolean;
  begin
    selection := gtk_tree_view_get_selection(GTK_TREE_VIEW(data));
    if gtk_tree_selection_get_selected(selection, @model, @iter) then
    begin
      // Obtener el índice de la fila seleccionada
      path := gtk_tree_model_get_path(model, @iter);
      indices := gtk_tree_path_get_indices(path);
      indice := indices^;
      gtk_tree_path_free(path);
      
      // Buscar el correo por posición en la lista filtrada
      aux := CorreosGlobal.primero;
      anterior := nil;
      contador := 0;
      encontrado := False;
      
      while aux <> nil do
      begin
        if (LowerCase(aux^.destinatario) = LowerCase(usuario.email)) and (aux^.estado <> 'DEL') then
        begin
          if contador = indice then
          begin
            encontrado := True;
            Break;
          end;
          Inc(contador);
        end;
        anterior := aux;
        aux := aux^.siguiente;
      end;
      
      if encontrado and (aux <> nil) then
      begin
        // Mover correo a la pila de papelera
        Push(PapeleraUsuarioActivo, aux^.id, aux^.remitente, aux^.asunto, aux^.fecha, aux^.contenido);
        
        // Remover de la lista global
        if anterior = nil then
          CorreosGlobal.primero := aux^.siguiente
        else
          anterior^.siguiente := aux^.siguiente;
          
        if aux = CorreosGlobal.ultimo then
          CorreosGlobal.ultimo := anterior;
        
        WriteLn('📧 Correo movido a papelera: ', aux^.asunto);
        
        // Liberar memoria del nodo original
        Dispose(aux);
        
        // Actualizar la tabla removiendo la fila
        gtk_list_store_remove(PGtkListStore(model), @iter);
      end;
    end;
  end;

begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), PChar('Bandeja de Entrada - ' + LimpiarUTF8(usuario.email)));
  gtk_window_set_default_size(GTK_WINDOW(window), 600, 400);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 0);

  // 4 columnas: Remitente | Asunto | Fecha | Estado
  store := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  treeview := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Remitente', renderer, 'text', 0, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 1, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Fecha', renderer, 'text', 2, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Estado', renderer, 'text', 3, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  gtk_container_add(GTK_CONTAINER(scroll), treeview);

  // Contenedor para botones
  hboxBotones := gtk_hbox_new(FALSE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hboxBotones, FALSE, FALSE, 5);

  // Botón Mover a Papelera
  btnEliminar := gtk_button_new_with_label('🗑️ Mover a Papelera');
  g_signal_connect(btnEliminar, 'clicked', G_CALLBACK(@OnEliminarClicked), treeview);
  gtk_box_pack_start(GTK_BOX(hboxBotones), btnEliminar, FALSE, FALSE, 5);

  // Insertar SOLO correos para el usuario activo (destinatario) que NO estén eliminados
  correosEncontrados := 0;
  aux := CorreosGlobal.primero;
  while aux <> nil do
  begin
    // Mostrar correos destinados a este usuario que no estén eliminados
    if (LowerCase(aux^.destinatario) = LowerCase(usuario.email)) and (aux^.estado <> 'DEL') then
    begin
      gtk_list_store_append(store, @iter);
      gtk_list_store_set(store, @iter,
        0, PChar(LimpiarUTF8(aux^.remitente)),
        1, PChar(LimpiarUTF8(aux^.asunto)),
        2, PChar(LimpiarUTF8(aux^.fecha)),
        3, PChar(LimpiarUTF8(aux^.estado)),
        -1);
      Inc(correosEncontrados);
    end;
    aux := aux^.siguiente;
  end;

  WriteLn('📧 Correos en bandeja para ', usuario.email, ': ', correosEncontrados);

  // Doble clic en una fila → abre detalle
  g_signal_connect(treeview, 'row-activated', G_CALLBACK(@OnRowActivated), nil);

  gtk_widget_show_all(window);
end;

end.