unit registro_usuario;

{$mode objfpc}{$H+}

interface

uses
  sysutils, glib2, gtk2, lista_simple;

procedure MostrarRegistro(var lista: TListaUsuarios);

implementation

var
  entryNombre, entryUsuario, entryEmail, entryTelefono, entryPass: PGtkWidget;
  pLista: ^TListaUsuarios; // guardamos referencia a la lista recibida

procedure on_guardar_clicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombre, usuario, email, telefono, password: String;
  idnuevo: Integer;
begin
  nombre := gtk_entry_get_text(GTK_ENTRY(entryNombre));
  usuario := gtk_entry_get_text(GTK_ENTRY(entryUsuario));
  email := gtk_entry_get_text(GTK_ENTRY(entryEmail));
  telefono := gtk_entry_get_text(GTK_ENTRY(entryTelefono));
  password := gtk_entry_get_text(GTK_ENTRY(entryPass));

  if (Trim(nombre) = '') or (Trim(usuario) = '') or (Trim(email) = '') or (Trim(password) = '') then
  begin
    WriteLn('Campos obligatorios vacíos');
    Exit;
  end;

  idnuevo := ObtenerSiguienteID(pLista^);
  InsertarUsuario(pLista^, idnuevo, nombre, usuario, email, telefono, password);
  WriteLn('Usuario creado: ', email, ' (ID ', idnuevo, ')');

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
  gtk_window_set_default_size(GTK_WINDOW(window), 380, 280);

  vbox := gtk_vbox_new(FALSE, 8);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  grid := gtk_table_new(5, 2, False);
  gtk_box_pack_start(GTK_BOX(vbox), grid, TRUE, TRUE, 0);

  // Nombre
  lbl := gtk_label_new('Nombre:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 0,1);
  entryNombre := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryNombre, 1,2, 0,1);

  // Usuario
  lbl := gtk_label_new('Usuario:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 1,2);
  entryUsuario := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryUsuario, 1,2, 1,2);

  // Email
  lbl := gtk_label_new('Email:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 2,3);
  entryEmail := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryEmail, 1,2, 2,3);

  // Teléfono
  lbl := gtk_label_new('Teléfono:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 3,4);
  entryTelefono := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryTelefono, 1,2, 3,4);

  // Password
  lbl := gtk_label_new('Contraseña:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 4,5);
  entryPass := gtk_entry_new;
  gtk_entry_set_visibility(GTK_ENTRY(entryPass), False);
  gtk_table_attach_defaults(GTK_TABLE(grid), entryPass, 1,2, 4,5);

  // Botones
  hboxBtns := gtk_hbox_new(TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hboxBtns, FALSE, FALSE, 0);

  btnGuardar := gtk_button_new_with_label('Guardar');
  g_signal_connect(btnGuardar, 'clicked', G_CALLBACK(@on_guardar_clicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBtns), btnGuardar, TRUE, TRUE, 0);

  btnCancelar := gtk_button_new_with_label('Cancelar');
  g_signal_connect(btnCancelar, 'clicked', G_CALLBACK(@on_cancelar_clicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBtns), btnCancelar, TRUE, TRUE, 0);

  gtk_widget_show_all(window);
end;

end.
