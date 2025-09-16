unit agregar_contacto;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, SysUtils, lista_circular, globals;

procedure MostrarAgregarContacto;

implementation

var
  entryNombre, entryUsuario, entryEmail, entryTelefono, entryNombreUsuario: PGtkWidget;

procedure OnAgregarClicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombre, usuario, email, nombreUsuario, telefono: String;
  nuevoId: Integer;
begin
  nombre := gtk_entry_get_text(GTK_ENTRY(entryNombre));
  usuario := gtk_entry_get_text(GTK_ENTRY(entryUsuario));
  email := gtk_entry_get_text(GTK_ENTRY(entryEmail));
  telefono := gtk_entry_get_text(GTK_ENTRY(entryTelefono));
  nombreUsuario := gtk_entry_get_text(GTK_ENTRY(entryNombreUsuario));

  if (Trim(nombre) = '') or (Trim(usuario) = '') or (Trim(email) = '') or (Trim(telefono) = '') or (Trim(nombreUsuario) = '') then
  begin
    WriteLn('⚠️ Todos los campos son obligatorios');
    Exit;
  end;

  // Validar formato de email básico
  if Pos('@', email) = 0 then
  begin
    WriteLn('⚠️ Email inválido');
    Exit;
  end;

  // Verificar si el contacto ya existe en los contactos del usuario actual
  if BuscarContacto(ContactosUsuarioActivo, email) <> nil then
  begin
    WriteLn('⚠️ El contacto con email ', email, ' ya existe en tu lista');
    Exit;
  end;

  //Validar duplicados por nombre de usuario
  if BuscarContactoPorUsuario(ContactosUsuarioActivo, usuario) <> nil then
  begin
    WriteLn('⚠️ El contacto con usuario ', usuario, ' ya existe en tu lista');
    Exit;
  end;

  // Generar ID único
  nuevoId := Random(1000000);

  // Insertar contacto en la lista del usuario actual
  InsertarContacto(ContactosUsuarioActivo, nuevoId, nombre, email, nombreUsuario);

  WriteLn('✅ Contacto agregado exitosamente para ', UsuarioActivo.email);
  WriteLn('   Nombre: ', nombre, ' | Usuario: ', usuario, ' | Email: ', email, ' | Tel: ', telefono, ' | Nombre de Usuario: ', nombreUsuario);

  // Limpiar campos
  gtk_entry_set_text(GTK_ENTRY(entryNombre), '');
  gtk_entry_set_text(GTK_ENTRY(entryUsuario), '');
  gtk_entry_set_text(GTK_ENTRY(entryNombreUsuario), '');
  gtk_entry_set_text(GTK_ENTRY(entryEmail), '');
  gtk_entry_set_text(GTK_ENTRY(entryTelefono), '');
end;

procedure MostrarVentanaContactos;
var
  window, vbox, scroll, treeview, lblUsuario: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  iter: TGtkTreeIter;
  aux: PContacto;
  contador: Integer;
  tituloUsuario: String;
begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Lista de Contactos');
  gtk_window_set_default_size(GTK_WINDOW(window), 600, 400);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Mostrar a qué usuario pertenecen los contactos
  tituloUsuario := 'Contactos de: ' + UsuarioActivo.email;
  lblUsuario := gtk_label_new(PChar('<b>' + tituloUsuario + '</b>'));
  gtk_label_set_use_markup(GTK_LABEL(lblUsuario), TRUE);
  gtk_box_pack_start(GTK_BOX(vbox), lblUsuario, FALSE, FALSE, 5);

  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 0);

  // 4 columnas: ID | Nombre | Email | Usuario
  store := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  treeview := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('ID', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 80);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Nombre', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Email', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 250);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Usuario', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  gtk_container_add(GTK_CONTAINER(scroll), treeview);

  // Llenar la tabla con los contactos del usuario actual
  if ContactosUsuarioActivo.primero <> nil then
  begin
    aux := ContactosUsuarioActivo.primero;
    contador := 0;
    repeat
      gtk_list_store_append(store, @iter);
      gtk_list_store_set(store, @iter,
        0, PChar(IntToStr(aux^.id)),
        1, PChar(aux^.nombre),
        2, PChar(aux^.email),
        3, PChar(aux^.nombreUsuario),
        -1);
      aux := aux^.siguiente;
      Inc(contador);
    until (aux = ContactosUsuarioActivo.primero) or (contador >= 50); // Límite de 50 para evitar loops infinitos
  end;

  gtk_widget_show_all(window);
end;

procedure OnVerContactosClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarVentanaContactos;
end;

procedure MostrarAgregarContacto;
var
  window, vbox, hbox, lbl: PGtkWidget;
  hboxBotones, btnAgregar, btnVerContactos: PGtkWidget;
  tituloUsuario: String;
begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Agregar Contacto');
  gtk_window_set_default_size(GTK_WINDOW(window), 450, 350);

  vbox := gtk_vbox_new(FALSE, 8);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Título con usuario actual
  tituloUsuario := 'Agregar Contacto para: ' + UsuarioActivo.email;
  lbl := gtk_label_new(PChar('<b>' + tituloUsuario + '</b>'));
  gtk_label_set_use_markup(GTK_LABEL(lbl), TRUE);
  gtk_box_pack_start(GTK_BOX(vbox), lbl, FALSE, FALSE, 5);

  // Nombre:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Nombre:');
  gtk_widget_set_size_request(lbl, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryNombre := gtk_entry_new;
  gtk_box_pack_start(GTK_BOX(hbox), entryNombre, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Usuario:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Usuario:');
  gtk_widget_set_size_request(lbl, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryUsuario := gtk_entry_new;
  gtk_box_pack_start(GTK_BOX(hbox), entryUsuario, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Nombre de Usuario:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Nombre de Usuario:');
  gtk_widget_set_size_request(lbl, 120, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryNombreUsuario := gtk_entry_new;
  gtk_box_pack_start(GTK_BOX(hbox), entryNombreUsuario, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Email:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Email:');
  gtk_widget_set_size_request(lbl, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryEmail := gtk_entry_new;
  gtk_box_pack_start(GTK_BOX(hbox), entryEmail, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Teléfono:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Teléfono:');
  gtk_widget_set_size_request(lbl, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryTelefono := gtk_entry_new;
  gtk_box_pack_start(GTK_BOX(hbox), entryTelefono, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Botones
  hboxBotones := gtk_hbox_new(TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hboxBotones, FALSE, FALSE, 15);

  btnAgregar := gtk_button_new_with_label('👥 Agregar Contacto');
  g_signal_connect(btnAgregar, 'clicked', G_CALLBACK(@OnAgregarClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBotones), btnAgregar, TRUE, TRUE, 5);

  btnVerContactos := gtk_button_new_with_label('📋 Ver Contactos');
  g_signal_connect(btnVerContactos, 'clicked', G_CALLBACK(@OnVerContactosClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBotones), btnVerContactos, TRUE, TRUE, 5);

  gtk_widget_show_all(window);
end;

end.
end;

end.