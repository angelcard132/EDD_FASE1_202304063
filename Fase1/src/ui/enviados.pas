unit enviados;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, SysUtils, lista_doble, globals, papelera;

procedure MostrarEnviados;

implementation

function LimpiarUTF8Enviados(const texto: String): String;
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
  window, vbox, labelInfo, textView, scroll, btnEliminar: PGtkWidget;
  buffer: PGtkTextBuffer;
  detalle: String;

  procedure OnEliminarClicked(widget: PGtkWidget; data: gpointer); cdecl;
  begin
    if correo <> nil then
    begin
      correo^.estado := 'DEL';  // marcar como eliminado
      WriteLn('✅ Correo enviado eliminado: ', correo^.asunto);
      gtk_widget_destroy(window); // cerrar ventana de detalle
    end;
  end;

begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Detalle del Correo Enviado');
  gtk_window_set_default_size(GTK_WINDOW(window), 450, 350);
  gtk_window_set_modal(GTK_WINDOW(window), TRUE);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  detalle :=
    'De: ' + LimpiarUTF8Enviados(correo^.remitente) + LineEnding +
    'Para: ' + LimpiarUTF8Enviados(correo^.destinatario) + LineEnding +
    'Asunto: ' + LimpiarUTF8Enviados(correo^.asunto) + LineEnding +
    'Fecha: ' + LimpiarUTF8Enviados(correo^.fecha) + LineEnding +
    'Estado: ENVIADO';

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
    gtk_text_buffer_set_text(buffer, PChar(LimpiarUTF8Enviados(correo^.contenido)), -1)
  else
    gtk_text_buffer_set_text(buffer, PChar('(Sin contenido)'), -1);
    
  gtk_container_add(GTK_CONTAINER(scroll), textView);

  // Botón para eliminar
  btnEliminar := gtk_button_new_with_label('🗑 Eliminar');
  g_signal_connect(btnEliminar, 'clicked', G_CALLBACK(@OnEliminarClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnEliminar, FALSE, FALSE, 5);

  gtk_widget_show_all(window);
end;

procedure OnRowActivated(treeview: PGtkTreeView; path: PGtkTreePath; column: PGtkTreeViewColumn; user_data: gpointer); cdecl;
var
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  pDest: Pgchar = nil;
  pAsu: Pgchar = nil;
  pFec: Pgchar = nil;
  sDest, sAsu, sFec: String;
  aux: PCorreo;
begin
  model := gtk_tree_view_get_model(treeview);
  if gtk_tree_model_get_iter(model, @iter, path) then
  begin
    try
      gtk_tree_model_get(model, @iter, 0, @pDest, 1, @pAsu, 2, @pFec, -1);
      if pDest <> nil then sDest := LimpiarUTF8Enviados(StrPas(pDest));
      if pAsu <> nil then sAsu := LimpiarUTF8Enviados(StrPas(pAsu));
      if pFec <> nil then sFec := LimpiarUTF8Enviados(StrPas(pFec));

      aux := CorreosGlobal.primero;
      while aux <> nil do
      begin
        if (LimpiarUTF8Enviados(aux^.destinatario) = sDest) and 
           (LimpiarUTF8Enviados(aux^.asunto) = sAsu) and 
           (LimpiarUTF8Enviados(aux^.fecha) = sFec) and
           (LowerCase(aux^.remitente) = LowerCase(UsuarioActivo.email)) then
        begin
          MostrarDetalleCorreo(aux);
          Break;
        end;
        aux := aux^.siguiente;
      end;
    finally
      if pDest <> nil then g_free(pDest);
      if pAsu <> nil then g_free(pAsu);
      if pFec <> nil then g_free(pFec);
    end;
  end;
end;

procedure MostrarEnviados;
var
  window, vbox, scroll, treeview, lblUsuario: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  iter: TGtkTreeIter;
  aux: PCorreo;
  tituloUsuario: String;
  correosEnviados: Integer;
begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Correos Enviados');
  gtk_window_set_default_size(GTK_WINDOW(window), 650, 400);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Mostrar a qué usuario pertenecen los correos enviados
  tituloUsuario := 'Correos enviados por: ' + UsuarioActivo.email;
  lblUsuario := gtk_label_new(PChar('<b>' + tituloUsuario + '</b>'));
  gtk_label_set_use_markup(GTK_LABEL(lblUsuario), TRUE);
  gtk_box_pack_start(GTK_BOX(vbox), lblUsuario, FALSE, FALSE, 5);

  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 0);

  // 4 columnas: Destinatario | Asunto | Fecha | Estado
  store := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  treeview := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Destinatario', renderer, 'text', 0, nil);
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

  // Filtrar correos enviados por el usuario activo (solo los no eliminados)
  correosEnviados := 0;
  aux := CorreosGlobal.primero;
  while aux <> nil do
  begin
    if (LowerCase(aux^.remitente) = LowerCase(UsuarioActivo.email)) and (aux^.estado <> 'DEL') then
    begin
      gtk_list_store_append(store, @iter);
      gtk_list_store_set(store, @iter,
        0, PChar(LimpiarUTF8Enviados(aux^.destinatario)),
        1, PChar(LimpiarUTF8Enviados(aux^.asunto)),
        2, PChar(LimpiarUTF8Enviados(aux^.fecha)),
        3, PChar('ENVIADO'),
        -1);
      Inc(correosEnviados);
    end;
    aux := aux^.siguiente;
  end;

  WriteLn('📤 Correos enviados por ', UsuarioActivo.email, ': ', correosEnviados);

  g_signal_connect(treeview, 'row-activated', G_CALLBACK(@OnRowActivated), nil);

  gtk_widget_show_all(window);
end;

end.