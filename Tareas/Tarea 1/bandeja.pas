unit bandeja;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, lista_doble, lista_simple, SysUtils;

procedure MostrarBandeja(const usuario: TUsuario; var listaCorreos: TListaCorreos);

implementation

var
  CorreosRef: ^TListaCorreos;

function LimpiarUTF8(const texto: String): String;
var
  i: Integer;
  resultado: String;
  c: Char;
begin
  resultado := '';
  for i := 1 to Length(texto) do
  begin
    c := texto[i];
    // Only include printable ASCII characters and basic UTF-8
    if (Ord(c) >= 32) and (Ord(c) <= 126) then
      resultado := resultado + c
    else if Ord(c) = 10 then // Line feed
      resultado := resultado + c
    else if Ord(c) = 13 then // Carriage return
      resultado := resultado + c
    else if Ord(c) = 9 then // Tab
      resultado := resultado + c
    else
      resultado := resultado + '?'; // Replace problematic characters
  end;
  Result := resultado;
end;

procedure MostrarDetalleCorreo(correo: PCorreo);
var
  window, vbox, labelInfo, textView, scroll: PGtkWidget;
  buffer: PGtkTextBuffer;
  detalle, mensajeLimpio: String;
begin
  // Debug output to check if message field has content
  WriteLn('Debug: Mostrando correo con mensaje: "', correo^.mensaje, '"');
  
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Detalle del Correo');
  gtk_window_set_default_size(GTK_WINDOW(window), 450, 350);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  detalle := 'De: ' + LimpiarUTF8(correo^.remitente) + LineEnding +
             'Asunto: ' + LimpiarUTF8(correo^.asunto) + LineEnding +
             'Estado: ' + LimpiarUTF8(correo^.estado) + LineEnding +
             'Fecha: ' + LimpiarUTF8(correo^.fecha);

  labelInfo := gtk_label_new(PChar(detalle));
  gtk_box_pack_start(GTK_BOX(vbox), labelInfo, FALSE, FALSE, 5);

  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 5);

  textView := gtk_text_view_new;
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(textView), GTK_WRAP_WORD);
  gtk_text_view_set_editable(GTK_TEXT_VIEW(textView), FALSE);
  buffer := gtk_text_view_get_buffer(GTK_TEXT_VIEW(textView));
  
  // Check if message is empty and provide fallback
  if Trim(correo^.mensaje) = '' then
  begin
    WriteLn('Warning: Mensaje está vacío para el correo: ', correo^.asunto);
    gtk_text_buffer_set_text(buffer, PChar('(Sin contenido)'), -1);
  end
  else
  begin
    // Clean the message text to ensure valid UTF-8
    mensajeLimpio := LimpiarUTF8(correo^.mensaje);
    WriteLn('Debug: Mensaje limpio: "', mensajeLimpio, '"');
    gtk_text_buffer_set_text(buffer, PChar(mensajeLimpio), -1);
  end;
  
  gtk_container_add(GTK_CONTAINER(scroll), textView);

  gtk_widget_show_all(window);
end;

procedure OnRowActivated(treeview: PGtkTreeView; path: PGtkTreePath; column: PGtkTreeViewColumn; user_data: gpointer); cdecl;
var
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  pRem, pAsu, pFec: Pgchar;
  sRem, sAsu, sFec: String;
  aux: PCorreo;
begin
  model := gtk_tree_view_get_model(treeview);
  if gtk_tree_model_get_iter(model, @iter, path) then
  begin
    // Obtener datos de la fila
    gtk_tree_model_get(model, @iter, 0, @pRem, 1, @pAsu, 3, @pFec, -1);
    
    try
      sRem := StrPas(pRem);
      sAsu := StrPas(pAsu);
      sFec := StrPas(pFec);

      // Buscar el correo correspondiente usando la referencia local
      aux := CorreosRef^.primero;
      while aux <> nil do
      begin
        if (aux^.remitente = sRem) and (aux^.asunto = sAsu) and (aux^.fecha = sFec) then
        begin
          // Marcar como leído
          aux^.estado := 'L';
          MostrarDetalleCorreo(aux);
          // Actualizar la tabla
          gtk_list_store_set(PGtkListStore(model), @iter, 2, PChar('L'), -1);
          Break;
        end;
        aux := aux^.siguiente;
      end;
    finally
      if pRem <> nil then g_free(pRem);
      if pAsu <> nil then g_free(pAsu);
      if pFec <> nil then g_free(pFec);
    end;
  end;
end;

procedure MostrarBandeja(const usuario: TUsuario; var listaCorreos: TListaCorreos);
var
  window, vbox, scroll, treeview: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  iter: TGtkTreeIter;
  aux: PCorreo;
  correosEncontrados: Integer;
begin
  // Set the reference for use in callbacks
  CorreosRef := @listaCorreos;

  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), PChar('Bandeja de Entrada - ' + usuario.email));
  gtk_window_set_default_size(GTK_WINDOW(window), 600, 400);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 0);

  // Crear tabla con columnas: Remitente | Asunto | Estado | Fecha
  store := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  treeview := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Remitente', renderer, 'text', 0, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 1, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Estado', renderer, 'text', 2, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Fecha', renderer, 'text', 3, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  gtk_container_add(GTK_CONTAINER(scroll), treeview);

  // Cargar SOLO correos para este usuario (como destinatario)
  correosEncontrados := 0;
  aux := listaCorreos.primero;
  while aux <> nil do
  begin
    // Verificar si el usuario es el destinatario
    if LowerCase(aux^.destinatario) = LowerCase(usuario.email) then
    begin
      gtk_list_store_append(store, @iter);
      gtk_list_store_set(store, @iter,
        0, PChar(aux^.remitente),
        1, PChar(aux^.asunto),
        2, PChar(aux^.estado),
        3, PChar(aux^.fecha),
        -1);
      Inc(correosEncontrados);
    end;
    aux := aux^.siguiente;
  end;

  WriteLn('Correos mostrados en bandeja para ', usuario.email, ': ', correosEncontrados);

  // Conectar evento doble clic
  g_signal_connect(treeview, 'row-activated', G_CALLBACK(@OnRowActivated), nil);

  gtk_widget_show_all(window);
end;

end.