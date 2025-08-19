unit bandeja;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, lista_doble;

procedure MostrarBandeja(lista: TListaCorreos);

implementation

procedure MostrarBandeja(lista: TListaCorreos);
var
  window, scroll, treeview: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  iter: TGtkTreeIter;
  aux: PCorreo;
begin
  // Crear ventana
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'EDDMail - Bandeja de Entrada');
  gtk_window_set_default_size(GTK_WINDOW(window), 600, 400);

  // Crear modelo de datos (ID, Estado, Asunto, Remitente, Fecha)
  store := gtk_list_store_new(5, G_TYPE_INT, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);

  // Crear TreeView
  treeview := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  g_object_unref(store);

  // Columnas
  renderer := gtk_cell_renderer_text_new();

  column := gtk_tree_view_column_new_with_attributes('ID', renderer, 'text', 0, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  column := gtk_tree_view_column_new_with_attributes('Estado', renderer, 'text', 1, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 2, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  column := gtk_tree_view_column_new_with_attributes('Remitente', renderer, 'text', 3, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  column := gtk_tree_view_column_new_with_attributes('Fecha', renderer, 'text', 4, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  // Llenar la tabla con los correos de la lista
  aux := lista.primero;
  while aux <> nil do
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
      0, aux^.id,
      1, PChar(aux^.estado),
      2, PChar(aux^.asunto),
      3, PChar(aux^.remitente),
      4, PChar(aux^.fecha),
      -1
    );
    aux := aux^.siguiente;
  end;

  // Scroll + integración
  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_container_add(GTK_CONTAINER(scroll), treeview);
  gtk_container_add(GTK_CONTAINER(window), scroll);

  // Mostrar ventana
  gtk_widget_show_all(window);
end;

end.
