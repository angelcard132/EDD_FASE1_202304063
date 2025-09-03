unit bandeja;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, lista_doble, lista_simple, json_loader, SysUtils, StrUtils, papelera, globals, redactar, pila;

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
  window, vbox, hboxBotones, hboxOrden, scroll, treeview, btnEliminar: PGtkWidget;
  lblOrden, btnOrdenAZ, btnOrdenZA, btnOrdenFechaAsc, btnOrdenFechaDesc: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  iter: TGtkTreeIter;
  aux: PCorreo;
  correosEncontrados: Integer;
  
  procedure ActualizarTablaOrdenada(ordenarPor: String; ascendente: Boolean);
  var
    listaCorreos: array of PCorreo;
    i, j, totalCorreos: Integer;
    temp: PCorreo;
    intercambio: Boolean;
    comparacion: Integer;
  begin
    // Limpiar tabla actual
    gtk_list_store_clear(store);
    
    // Recopilar correos del usuario en array
    SetLength(listaCorreos, 0);
    aux := CorreosGlobal.primero;
    while aux <> nil do
    begin
      if (LowerCase(aux^.destinatario) = LowerCase(usuario.email)) and (aux^.estado <> 'DEL') then
      begin
        SetLength(listaCorreos, Length(listaCorreos) + 1);
        listaCorreos[High(listaCorreos)] := aux;
      end;
      aux := aux^.siguiente;
    end;
    
    totalCorreos := Length(listaCorreos);
    if totalCorreos = 0 then Exit;
    
    // Ordenamiento burbuja
    for i := 0 to totalCorreos - 2 do
    begin
      intercambio := False;
      for j := 0 to totalCorreos - i - 2 do
      begin
        // Determinar comparación según el criterio
        if ordenarPor = 'asunto' then
          comparacion := CompareText(listaCorreos[j]^.asunto, listaCorreos[j + 1]^.asunto)
        else if ordenarPor = 'remitente' then
          comparacion := CompareText(listaCorreos[j]^.remitente, listaCorreos[j + 1]^.remitente)
        else if ordenarPor = 'fecha' then
          comparacion := CompareText(listaCorreos[j]^.fecha, listaCorreos[j + 1]^.fecha)
        else
          comparacion := 0;
        
        // Aplicar dirección de ordenamiento
        if not ascendente then
          comparacion := -comparacion;
        
        if comparacion > 0 then
        begin
          temp := listaCorreos[j];
          listaCorreos[j] := listaCorreos[j + 1];
          listaCorreos[j + 1] := temp;
          intercambio := True;
        end;
      end;
      if not intercambio then Break; // Ya está ordenado
    end;
    
    // Llenar tabla con datos ordenados
    for i := 0 to totalCorreos - 1 do
    begin
      gtk_list_store_append(store, @iter);
      gtk_list_store_set(store, @iter,
        0, PChar(LimpiarUTF8(listaCorreos[i]^.remitente)),
        1, PChar(LimpiarUTF8(listaCorreos[i]^.asunto)),
        2, PChar(LimpiarUTF8(listaCorreos[i]^.fecha)),
        3, PChar(LimpiarUTF8(listaCorreos[i]^.estado)),
        -1);
    end;
    
    if ascendente then
      WriteLn('📧 Correos ordenados por ', ordenarPor, ' (A-Z): ', totalCorreos, ' correos')
    else
      WriteLn('📧 Correos ordenados por ', ordenarPor, ' (Z-A): ', totalCorreos, ' correos');
  end;
  
  procedure OnOrdenAZClicked(widget: PGtkWidget; data: gpointer); cdecl;
  begin
    WriteLn('🔤 Ordenando por asunto A-Z...');
    ActualizarTablaOrdenada('asunto', True);
  end;
  
  procedure OnOrdenZAClicked(widget: PGtkWidget; data: gpointer); cdecl;
  begin
    WriteLn('🔤 Ordenando por asunto Z-A...');
    ActualizarTablaOrdenada('asunto', False);
  end;
  
  procedure OnOrdenFechaAscClicked(widget: PGtkWidget; data: gpointer); cdecl;
  begin
    WriteLn('📅 Ordenando por fecha (más antiguos primero)...');
    ActualizarTablaOrdenada('fecha', True);
  end;
  
  procedure OnOrdenFechaDescClicked(widget: PGtkWidget; data: gpointer); cdecl;
  begin
    WriteLn('📅 Ordenando por fecha (más recientes primero)...');
    ActualizarTablaOrdenada('fecha', False);
  end;
  
  procedure CargarCorreosIniciales;
  begin
    // Cargar correos sin ordenamiento (orden original)
    aux := CorreosGlobal.primero;
    correosEncontrados := 0;
    while aux <> nil do
    begin
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
  end;

  procedure OnEliminarClicked(widget: PGtkWidget; data: gpointer); cdecl;
  var
    selection: PGtkTreeSelection;
    model: PGtkTreeModel;
    iter: TGtkTreeIter;
    pRem, pAsu, pFec: Pgchar;
    sRem, sAsu, sFec: String;
    aux, anterior: PCorreo;
    encontrado: Boolean;
  begin
    selection := gtk_tree_view_get_selection(GTK_TREE_VIEW(data));
    if not gtk_tree_selection_get_selected(selection, @model, @iter) then
    begin
      WriteLn('⚠️ Selecciona un correo para mover a papelera');
      Exit;
    end;

    // Obtener datos de la fila seleccionada
    pRem := nil; pAsu := nil; pFec := nil;
    try
      gtk_tree_model_get(model, @iter, 0, @pRem, 1, @pAsu, 2, @pFec, -1);
      
      if (pRem = nil) or (pAsu = nil) or (pFec = nil) then
      begin
        WriteLn('❌ Error obteniendo datos del correo seleccionado');
        Exit;
      end;
      
      sRem := StrPas(pRem);
      sAsu := StrPas(pAsu);
      sFec := StrPas(pFec);
      
      WriteLn('🔍 Buscando correo: ', sRem, ' -> ', sAsu, ' (', sFec, ')');
      
      // Buscar el correo en la lista global usando los datos exactos
      aux := CorreosGlobal.primero;
      anterior := nil;
      encontrado := False;
      
      while aux <> nil do
      begin
        if (LimpiarUTF8(aux^.remitente) = sRem) and 
           (LimpiarUTF8(aux^.asunto) = sAsu) and 
           (LimpiarUTF8(aux^.fecha) = sFec) and
           (LowerCase(aux^.destinatario) = LowerCase(usuario.email)) and
           (aux^.estado <> 'DEL') then
        begin
          encontrado := True;
          Break;
        end;
        anterior := aux;
        aux := aux^.siguiente;
      end;
      
      if not encontrado or (aux = nil) then
      begin
        WriteLn('❌ No se encontró el correo en la lista global');
        Exit;
      end;
      
      WriteLn('✅ Correo encontrado: ID ', aux^.id, ' - ', aux^.asunto);
      
      // Mover correo a la pila de papelera
      Push(PapeleraUsuarioActivo, aux^.id, aux^.remitente, aux^.asunto, aux^.fecha, aux^.contenido);
      WriteLn('📧 Correo agregado a papelera: ', aux^.asunto);
      
      // Remover de la lista global de forma segura
      if anterior = nil then
      begin
        // Es el primer elemento
        CorreosGlobal.primero := aux^.siguiente;
        if CorreosGlobal.ultimo = aux then
          CorreosGlobal.ultimo := nil;
      end
      else
      begin
        // No es el primer elemento
        anterior^.siguiente := aux^.siguiente;
        if CorreosGlobal.ultimo = aux then
          CorreosGlobal.ultimo := anterior;
      end;
      
      // Liberar memoria del nodo original
      Dispose(aux);
      
      // Remover de la tabla GTK
      gtk_list_store_remove(PGtkListStore(model), @iter);
      
      WriteLn('✅ Correo movido a papelera exitosamente');
      
    finally
      // Liberar memoria de glib
      if pRem <> nil then g_free(pRem);
      if pAsu <> nil then g_free(pAsu);
      if pFec <> nil then g_free(pFec);
    end;
  end;

begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), PChar('Bandeja de Entrada - ' + LimpiarUTF8(usuario.email)));
  gtk_window_set_default_size(GTK_WINDOW(window), 700, 500);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Sección de ordenamiento
  hboxOrden := gtk_hbox_new(FALSE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hboxOrden, FALSE, FALSE, 5);
  
  lblOrden := gtk_label_new('<b>Ordenar por:</b>');
  gtk_label_set_use_markup(GTK_LABEL(lblOrden), TRUE);
  gtk_box_pack_start(GTK_BOX(hboxOrden), lblOrden, FALSE, FALSE, 10);
  
  btnOrdenAZ := gtk_button_new_with_label('📝 Asunto A-Z');
  g_signal_connect(btnOrdenAZ, 'clicked', G_CALLBACK(@OnOrdenAZClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxOrden), btnOrdenAZ, FALSE, FALSE, 5);
  
  btnOrdenZA := gtk_button_new_with_label('📝 Asunto Z-A');
  g_signal_connect(btnOrdenZA, 'clicked', G_CALLBACK(@OnOrdenZAClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxOrden), btnOrdenZA, FALSE, FALSE, 5);
  
  btnOrdenFechaAsc := gtk_button_new_with_label('📅 Fecha ↑');
  g_signal_connect(btnOrdenFechaAsc, 'clicked', G_CALLBACK(@OnOrdenFechaAscClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxOrden), btnOrdenFechaAsc, FALSE, FALSE, 5);
  
  btnOrdenFechaDesc := gtk_button_new_with_label('📅 Fecha ↓');
  g_signal_connect(btnOrdenFechaDesc, 'clicked', G_CALLBACK(@OnOrdenFechaDescClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxOrden), btnOrdenFechaDesc, FALSE, FALSE, 5);

  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 0);

  // 4 columnas: Remitente | Asunto | Fecha | Estado
  store := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  treeview := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Remitente', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 200);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Fecha', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 100);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Estado', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 80);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  gtk_container_add(GTK_CONTAINER(scroll), treeview);

  // Contenedor para botones de acción
  hboxBotones := gtk_hbox_new(FALSE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hboxBotones, FALSE, FALSE, 5);

  btnEliminar := gtk_button_new_with_label('🗑️ Mover a Papelera');
  g_signal_connect(btnEliminar, 'clicked', G_CALLBACK(@OnEliminarClicked), treeview);
  gtk_box_pack_start(GTK_BOX(hboxBotones), btnEliminar, FALSE, FALSE, 5);

  // Cargar correos iniciales (sin ordenamiento)
  CargarCorreosIniciales;

  // Doble clic en una fila → abre detalle
  g_signal_connect(treeview, 'row-activated', G_CALLBACK(@OnRowActivated), nil);

  gtk_widget_show_all(window);
end;

end.