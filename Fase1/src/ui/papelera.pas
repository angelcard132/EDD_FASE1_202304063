unit papelera;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, SysUtils, lista_doble, globals;

procedure MostrarPapelera;

implementation

function LimpiarUTF8Papelera(const texto: String): String;
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
  window, vbox, labelInfo, textView, scroll, btnRestaurar: PGtkWidget;
  buffer: PGtkTextBuffer;
  detalle: String;
  
  procedure OnRestaurarClicked(widget: PGtkWidget; data: gpointer); cdecl;
  begin
    if correo <> nil then
    begin
      correo^.estado := 'NL';  // Restaurar correo
      WriteLn('✅ Correo restaurado: ', correo^.asunto);
      gtk_widget_destroy(window);
    end;
  end;

begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Detalle del Correo (Papelera)');
  gtk_window_set_default_size(GTK_WINDOW(window), 450, 350);
  gtk_window_set_modal(GTK_WINDOW(window), TRUE);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  detalle :=
    'De: ' + LimpiarUTF8Papelera(correo^.remitente) + LineEnding +
    'Para: ' + LimpiarUTF8Papelera(correo^.destinatario) + LineEnding +
    'Asunto: ' + LimpiarUTF8Papelera(correo^.asunto) + LineEnding +
    'Fecha: ' + LimpiarUTF8Papelera(correo^.fecha) + LineEnding +
    'Estado: ELIMINADO';

  labelInfo := gtk_label_new(PChar(detalle));
  gtk_label_set_selectable(GTK_LABEL(labelInfo), True);
  gtk_box_pack_start(GTK_BOX(vbox), labelInfo, FALSE, FALSE, 5);

  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 5);

  textView := gtk_text_view_new;
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(textView), GTK_WRAP_WORD);
  gtk_text_view_set_editable(GTK_TEXT_VIEW(textView), FALSE);
  buffer := gtk_text_view_get_buffer(GTK_TEXT_VIEW(textView));
  
  if correo^.contenido <> '' then
    gtk_text_buffer_set_text(buffer, PChar(LimpiarUTF8Papelera(correo^.contenido)), -1)
  else
    gtk_text_buffer_set_text(buffer, PChar('(Sin contenido)'), -1);

  gtk_container_add(GTK_CONTAINER(scroll), textView);

  // Botón para restaurar
  btnRestaurar := gtk_button_new_with_label('↩ Restaurar Correo');
  g_signal_connect(btnRestaurar, 'clicked', G_CALLBACK(@OnRestaurarClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRestaurar, FALSE, FALSE, 5);

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
    try
      gtk_tree_model_get(model, @iter, 0, @pRem, 1, @pAsu, 2, @pFec, -1);
      if pRem <> nil then sRem := LimpiarUTF8Papelera(StrPas(pRem));
      if pAsu <> nil then sAsu := LimpiarUTF8Papelera(StrPas(pAsu));
      if pFec <> nil then sFec := LimpiarUTF8Papelera(StrPas(pFec));

      aux := CorreosGlobal.primero;
      while aux <> nil do
      begin
        if (LimpiarUTF8Papelera(aux^.remitente) = sRem) and 
           (LimpiarUTF8Papelera(aux^.asunto) = sAsu) and 
           (LimpiarUTF8Papelera(aux^.fecha) = sFec) and 
           (aux^.estado = 'DEL') then
        begin
          MostrarDetalleCorreo(aux);
          // Actualizar estado en la tabla si fue restaurado
          gtk_list_store_set(PGtkListStore(model), @iter, 3, PChar(aux^.estado), -1);
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

procedure MostrarPapelera;
var
  window, vbox, scroll, treeview, lblUsuario, hboxBotones, btnActualizar: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  iter: TGtkTreeIter;
  aux: PCorreo;
  tituloUsuario: String;
  correosPapelera: Integer;
  
  procedure OnActualizarClicked(widget: PGtkWidget; data: gpointer); cdecl;
  var
    aux: PCorreo;
    nuevaStore: PGtkListStore;
    iter: TGtkTreeIter;
  begin
    // Limpiar y recargar la tabla
    nuevaStore := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
    
    aux := CorreosGlobal.primero;
    while aux <> nil do
    begin
      // Mostrar correos eliminados que involucren al usuario actual (enviados o recibidos)
      if (aux^.estado = 'DEL') and 
         ((LowerCase(aux^.destinatario) = LowerCase(UsuarioActivo.email)) or 
          (LowerCase(aux^.remitente) = LowerCase(UsuarioActivo.email))) then
      begin
        gtk_list_store_append(nuevaStore, @iter);
        gtk_list_store_set(nuevaStore, @iter,
          0, PChar(LimpiarUTF8Papelera(aux^.remitente)),
          1, PChar(LimpiarUTF8Papelera(aux^.asunto)),
          2, PChar(LimpiarUTF8Papelera(aux^.fecha)),
          3, PChar('ELIMINADO'),
          -1);
      end;
      aux := aux^.siguiente;
    end;
    
    gtk_tree_view_set_model(GTK_TREE_VIEW(treeview), GTK_TREE_MODEL(nuevaStore));
    WriteLn('🔄 Papelera actualizada');
  end;

begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Papelera');
  gtk_window_set_default_size(GTK_WINDOW(window), 650, 400);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Mostrar a qué usuario pertenece la papelera
  tituloUsuario := 'Papelera de: ' + UsuarioActivo.email;
  lblUsuario := gtk_label_new(PChar('<b>' + tituloUsuario + '</b>'));
  gtk_label_set_use_markup(GTK_LABEL(lblUsuario), TRUE);
  gtk_box_pack_start(GTK_BOX(vbox), lblUsuario, FALSE, FALSE, 5);

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
  gtk_tree_view_column_set_min_width(column, 100);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  gtk_container_add(GTK_CONTAINER(scroll), treeview);

  // Botones
  hboxBotones := gtk_hbox_new(FALSE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hboxBotones, FALSE, FALSE, 5);

  btnActualizar := gtk_button_new_with_label('🔄 Actualizar');
  g_signal_connect(btnActualizar, 'clicked', G_CALLBACK(@OnActualizarClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBotones), btnActualizar, FALSE, FALSE, 5);

  // Llenar la tabla con correos eliminados del usuario actual
  correosPapelera := 0;
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
