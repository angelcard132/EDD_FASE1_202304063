unit redactar2;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, SysUtils, lista_doble, lista_simple, lista_circular, globals;

procedure MostrarRedactar;

implementation

var
  entryPara, entryAsunto: PGtkWidget;
  textContenido: PGtkWidget;

procedure OnEnviarClicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  para, asunto, contenido, fecha: String;
  buffer: PGtkTextBuffer;
  startIter, endIter: TGtkTextIter;
  nuevoId: Integer;
  esUsuarioRegistrado: Boolean;
  contacto: PContacto;
begin
  para   := gtk_entry_get_text(GTK_ENTRY(entryPara));
  asunto := gtk_entry_get_text(GTK_ENTRY(entryAsunto));

  buffer := gtk_text_view_get_buffer(GTK_TEXT_VIEW(textContenido));
  gtk_text_buffer_get_start_iter(buffer, @startIter);
  gtk_text_buffer_get_end_iter(buffer, @endIter);
  contenido := gtk_text_buffer_get_text(buffer, @startIter, @endIter, True);

  fecha := DateToStr(Date);

  if (Trim(para) = '') or (Trim(asunto) = '') or (Trim(contenido) = '') then
  begin
    WriteLn('⚠️ Todos los campos son obligatorios');
    Exit;
  end;

  // Verificar si el destinatario es un usuario registrado o un contacto
  esUsuarioRegistrado := BuscarUsuarioPorUsuario(UsuariosGlobal, para) <> nil;
  contacto := BuscarContactoPorUsuario(ContactosUsuarioActivo, para);

  // VALIDACIÓN ESTRICTA: Solo permitir envío a usuarios registrados o contactos
  if not esUsuarioRegistrado and (contacto = nil) then
  begin
    WriteLn('❌ ERROR: No se puede enviar el correo');
    WriteLn('⚠️ El destinatario "', para, '" no está registrado en el sistema ni en tus contactos');
    WriteLn('💡 Para enviar correos debes:');
    WriteLn('   1. Que el destinatario sea un usuario registrado en el sistema, O');
    WriteLn('   2. Agregar el contacto a tu lista personal desde "👥 Agregar Contacto"');
    Exit;
  end;

  // Mostrar información del destinatario válido
  if esUsuarioRegistrado then
  begin
    WriteLn('📧 Enviando correo a usuario registrado: ', para);
  end
  else if contacto <> nil then
  begin
    WriteLn('📧 Enviando correo a contacto: ', contacto^.nombre, ' (', para, ')');
  end;

  // Asegurar lista global inicializada
  if (CorreosGlobal.primero = nil) and (CorreosGlobal.ultimo = nil) then
    InicializarListaCorreos(CorreosGlobal);

  // Generar ID único
  nuevoId := Random(1000000);

  // Insertar correo en la lista global (solo destinatarios válidos)
  InsertarCorreo(CorreosGlobal,
    nuevoId,                 // ID único
    UsuarioActivo.usuario,     // remitente
    para,                    // destinatario
    'NL',                    // estado inicial (no leído)
    asunto,                  // asunto
    fecha,                   // fecha
    contenido                // contenido
  );

  WriteLn('✅ Correo enviado exitosamente:');
  WriteLn('   ID: ', nuevoId);
  WriteLn('   De: ', UsuarioActivo.usuario, '(', UsuarioActivo.email, ')');
  WriteLn('   Para: ', para);
  WriteLn('   Asunto: ', asunto);
  WriteLn('   Estado: NL (No leído)');
  WriteLn('   Fecha: ', fecha);
  
  // Limpiar campos después de enviar
  gtk_entry_set_text(GTK_ENTRY(entryPara), '');
  gtk_entry_set_text(GTK_ENTRY(entryAsunto), '');
  gtk_text_buffer_set_text(buffer, '', -1);
end;

procedure MostrarRedactar;
var
  window, vbox, hbox, lbl: PGtkWidget;
  scroll, btnEnviar, btnContactos: PGtkWidget;
  
  procedure OnSeleccionarContactoClicked(widget: PGtkWidget; data: gpointer); cdecl;
  var
    dialogWindow, vboxDialog, scrollDialog, treeview: PGtkWidget;
    store: PGtkListStore;
    column: PGtkTreeViewColumn;
    renderer: PGtkCellRenderer;
    iter: TGtkTreeIter;
    aux: PContacto;
    contador: Integer;
    
    procedure OnContactoSeleccionado(treeview: PGtkTreeView; path: PGtkTreePath; column: PGtkTreeViewColumn; user_data: gpointer); cdecl;
    var
      model: PGtkTreeModel;
      iter: TGtkTreeIter;
      pEmail: Pgchar = nil;
      email: String;
    begin
      model := gtk_tree_view_get_model(treeview);
      if gtk_tree_model_get_iter(model, @iter, path) then
      begin
        try
          gtk_tree_model_get(model, @iter, 3, @pEmail, -1);
          if pEmail <> nil then
          begin
            email := StrPas(pEmail);
            gtk_entry_set_text(GTK_ENTRY(entryPara), PChar(email));
            WriteLn('📧 Contacto seleccionado: ', email);
            gtk_widget_destroy(dialogWindow);
          end;
        finally
          if pEmail <> nil then g_free(pEmail);
        end;
      end;
    end;

  begin
    dialogWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(dialogWindow), 'Seleccionar Contacto');
    gtk_window_set_default_size(GTK_WINDOW(dialogWindow), 400, 300);
    gtk_window_set_modal(GTK_WINDOW(dialogWindow), TRUE);

    vboxDialog := gtk_vbox_new(FALSE, 5);
    gtk_container_add(GTK_CONTAINER(dialogWindow), vboxDialog);

    scrollDialog := gtk_scrolled_window_new(nil, nil);
    gtk_box_pack_start(GTK_BOX(vboxDialog), scrollDialog, TRUE, TRUE, 5);

    store := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
    treeview := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));

    renderer := gtk_cell_renderer_text_new;
    column := gtk_tree_view_column_new_with_attributes('ID', renderer, 'text', 0, nil);
    gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

    renderer := gtk_cell_renderer_text_new;
    column := gtk_tree_view_column_new_with_attributes('Nombre', renderer, 'text', 1, nil);
    gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

    renderer := gtk_cell_renderer_text_new;
    column := gtk_tree_view_column_new_with_attributes('Email', renderer, 'text', 2, nil);
    gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

    renderer := gtk_cell_renderer_text_new;
    column := gtk_tree_view_column_new_with_attributes('Usuario', renderer, 'text', 3, nil);
    gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

    gtk_container_add(GTK_CONTAINER(scrollDialog), treeview);

    // Llenar con contactos
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
      until (aux = ContactosUsuarioActivo.primero) or (contador >= 50);
    end;

    g_signal_connect(treeview, 'row-activated', G_CALLBACK(@OnContactoSeleccionado), nil);
    gtk_widget_show_all(dialogWindow);
  end;

begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Redactar Correo');
  gtk_window_set_default_size(GTK_WINDOW(window), 450, 420);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Para:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Para:');
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryPara := gtk_entry_new;
  gtk_box_pack_start(GTK_BOX(hbox), entryPara, TRUE, TRUE, 5);
  
  // Botón para seleccionar contacto
  btnContactos := gtk_button_new_with_label('👥');
  g_signal_connect(btnContactos, 'clicked', G_CALLBACK(@OnSeleccionarContactoClicked), nil);
  gtk_box_pack_start(GTK_BOX(hbox), btnContactos, FALSE, FALSE, 5);
  
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Asunto:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Asunto:');
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryAsunto := gtk_entry_new;
  gtk_box_pack_start(GTK_BOX(hbox), entryAsunto, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Contenido:
  lbl := gtk_label_new('Contenido:');
  gtk_box_pack_start(GTK_BOX(vbox), lbl, FALSE, FALSE, 5);
  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 5);

  textContenido := gtk_text_view_new;
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(textContenido), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scroll), textContenido);

  // Enviar
  btnEnviar := gtk_button_new_with_label('Enviar');
  g_signal_connect(btnEnviar, 'clicked', G_CALLBACK(@OnEnviarClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnEnviar, FALSE, FALSE, 5);

  gtk_widget_show_all(window);
end;

end.
