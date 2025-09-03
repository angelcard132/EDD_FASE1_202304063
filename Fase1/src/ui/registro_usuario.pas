unit registro_usuario;

{$mode objfpc}{$H+}

interface

uses
  sysutils, glib2, gtk2, lista_simple;

procedure MostrarRegistro(var lista: TListaUsuarios);

implementation

var
  entryId, entryNombre, entryUsuario, entryEmail, entryTelefono, entryPass: PGtkWidget;
  pLista: ^TListaUsuarios; // guardamos referencia a la lista recibida

function BuscarUsuarioPorID(const lista: TListaUsuarios; id: Integer): PUsuario;
var
  aux: PUsuario;
begin
  aux := lista.primero;
  while (aux <> nil) and (aux^.id <> id) do
    aux := aux^.siguiente;
  BuscarUsuarioPorID := aux;
end;

procedure on_guardar_clicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombre, usuario, email, telefono, password, idTexto: String;
  idUsuario: Integer;
  usuarioExistente: PUsuario;
begin
  idTexto := gtk_entry_get_text(GTK_ENTRY(entryId));
  nombre := gtk_entry_get_text(GTK_ENTRY(entryNombre));
  usuario := gtk_entry_get_text(GTK_ENTRY(entryUsuario));
  email := gtk_entry_get_text(GTK_ENTRY(entryEmail));
  telefono := gtk_entry_get_text(GTK_ENTRY(entryTelefono));
  password := gtk_entry_get_text(GTK_ENTRY(entryPass));

  // Validar campos obligatorios
  if (Trim(idTexto) = '') or (Trim(nombre) = '') or (Trim(usuario) = '') or (Trim(email) = '') or (Trim(password) = '') then
  begin
    WriteLn('❌ Todos los campos son obligatorios');
    Exit;
  end;

  // Validar que el ID sea un número válido
  if not TryStrToInt(Trim(idTexto), idUsuario) then
  begin
    WriteLn('❌ El ID debe ser un número válido');
    Exit;
  end;

  // Validar que el ID sea positivo
  if idUsuario <= 0 then
  begin
    WriteLn('❌ El ID debe ser un número positivo');
    Exit;
  end;

  // Verificar si ya existe un usuario con ese ID
  usuarioExistente := BuscarUsuarioPorID(pLista^, idUsuario);
  if usuarioExistente <> nil then
  begin
    WriteLn('❌ ERROR: Ya existe un usuario con el ID ', idUsuario);
    WriteLn('   Usuario existente: ', usuarioExistente^.nombre, ' (', usuarioExistente^.email, ')');
    WriteLn('💡 Por favor, elija un ID diferente');
    Exit;
  end;

  // Verificar si ya existe un usuario con ese email
  usuarioExistente := BuscarUsuarioPorEmail(pLista^, email);
  if usuarioExistente <> nil then
  begin
    WriteLn('❌ ERROR: Ya existe un usuario con el email ', email);
    WriteLn('   Usuario existente: ', usuarioExistente^.nombre, ' (ID: ', usuarioExistente^.id, ')');
    WriteLn('💡 Por favor, use un email diferente');
    Exit;
  end;

  // Insertar el nuevo usuario con el ID especificado
  InsertarUsuario(pLista^, idUsuario, nombre, usuario, email, telefono, password);
  WriteLn('✅ Usuario creado exitosamente:');
  WriteLn('   ID: ', idUsuario);
  WriteLn('   Nombre: ', nombre);
  WriteLn('   Email: ', email);

  // Cerrar la ventana que contiene el botón
  gtk_widget_destroy(gtk_widget_get_toplevel(widget));
end;

procedure on_cancelar_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  gtk_widget_destroy(gtk_widget_get_toplevel(widget));
end;

procedure MostrarRegistro(var lista: TListaUsuarios);
var
  window, vbox, grid, hboxBtns: PGtkWidget;
  lbl: PGtkWidget;
  btnGuardar, btnCancelar: PGtkWidget;
begin
  pLista := @lista;

  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Registrar nuevo usuario');
  gtk_window_set_default_size(GTK_WINDOW(window), 380, 320);

  vbox := gtk_vbox_new(FALSE, 8);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  grid := gtk_table_new(6, 2, False);
  gtk_box_pack_start(GTK_BOX(vbox), grid, TRUE, TRUE, 0);

  // ID
  lbl := gtk_label_new('ID:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 0,1);
  entryId := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryId, 1,2, 0,1);

  // Nombre
  lbl := gtk_label_new('Nombre:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 1,2);
  entryNombre := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryNombre, 1,2, 1,2);

  // Usuario
  lbl := gtk_label_new('Usuario:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 2,3);
  entryUsuario := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryUsuario, 1,2, 2,3);

  // Email
  lbl := gtk_label_new('Email:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 3,4);
  entryEmail := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryEmail, 1,2, 3,4);

  // Teléfono
  lbl := gtk_label_new('Teléfono:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 4,5);
  entryTelefono := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryTelefono, 1,2, 4,5);

  // Password
  lbl := gtk_label_new('Contraseña:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 5,6);
  entryPass := gtk_entry_new;
  gtk_entry_set_visibility(GTK_ENTRY(entryPass), False);
  gtk_table_attach_defaults(GTK_TABLE(grid), entryPass, 1,2, 5,6);

  // Botones
  hboxBtns := gtk_hbox_new(TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hboxBtns, FALSE, FALSE, 0);

  btnGuardar := gtk_button_new_with_label('✅ Guardar');
  g_signal_connect(btnGuardar, 'clicked', G_CALLBACK(@on_guardar_clicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBtns), btnGuardar, TRUE, TRUE, 0);

  btnCancelar := gtk_button_new_with_label('❌ Cancelar');
  g_signal_connect(btnCancelar, 'clicked', G_CALLBACK(@on_cancelar_clicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBtns), btnCancelar, TRUE, TRUE, 0);

  gtk_widget_show_all(window);
end;

end.
end.
