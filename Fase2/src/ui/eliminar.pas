unit eliminar;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  pila2, json_loader;

procedure MostrarPapelera(const emailUsuario: String; var papelera: TPila);
procedure EliminarCorreoDeBandeja(correoID: Integer; const remitente, destinatario, asunto, mensaje: String; var papelera: TPila);

implementation

type
  PCorreoEliminadoUI = ^TCorreoEliminadoUI;
  TCorreoEliminadoUI = record
    id: Integer;
    remitente: String;
    destinatario: String;
    asunto: String;
    mensaje: String;
    siguiente: PCorreoEliminadoUI;
  end;

var
  GEmailUsuario: String;
  GPapelera: ^TPila;
  
  PapeleraWindow: PGtkWidget;
  ListaEliminados: PGtkWidget;
  TextViewDetalle: PGtkWidget;
  LabelInfo: PGtkWidget;
  
  EliminadoSeleccionado: Integer;

function SanearUTF8(const s: String): String;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(s) do
  begin
    c := s[i];
    if (Ord(c) >= 32) and (Ord(c) <> 127) then
      Result := Result + c
    else
      Result := Result + '?';
  end;
end;

procedure LiberarListaEliminadosUI(var lista: PCorreoEliminadoUI);
var
  actual, temp: PCorreoEliminadoUI;
begin
  actual := lista;
  while actual <> nil do
  begin
    temp := actual^.siguiente;
    Dispose(actual);
    actual := temp;
  end;
  lista := nil;
end;

procedure AgregarEliminadoALista(var lista: PCorreoEliminadoUI; const correo: pila2.PCorreo);
var
  nuevo: PCorreoEliminadoUI;
begin
  New(nuevo);
  nuevo^.id := correo^.id;
  nuevo^.remitente := correo^.remitente;
  nuevo^.destinatario := correo^.destinatario;
  nuevo^.asunto := correo^.asunto;
  nuevo^.mensaje := correo^.mensaje;
  nuevo^.siguiente := lista;
  lista := nuevo;
end;

function ObtenerEliminadosDelUsuario: PCorreoEliminadoUI;
var
  lista: PCorreoEliminadoUI;
  actual: pila2.PCorreo;
begin
  lista := nil;
  
  if GPapelera <> nil then
  begin
    actual := GPapelera^.tope;
    while actual <> nil do
    begin
      // Filtrar correos del usuario (recibidos o enviados)
      if (actual^.destinatario = GEmailUsuario) or (actual^.remitente = GEmailUsuario) then
        AgregarEliminadoALista(lista, actual);
      actual := actual^.siguiente;
    end;
  end;
  
  Result := lista;
end;

procedure CargarEliminadosEnLista;
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  lista, actual: PCorreoEliminadoUI;
  idStr: String;
  contador: Integer;
begin
  if ListaEliminados = nil then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaEliminados)));
  if store = nil then Exit;
  
  gtk_list_store_clear(store);
  
  lista := ObtenerEliminadosDelUsuario;
  actual := lista;
  contador := 0;
  
  while actual <> nil do
  begin
    idStr := IntToStr(actual^.id);
    
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar(SanearUTF8(idStr)),
                       1, PChar(SanearUTF8(actual^.remitente)),
                       2, PChar(SanearUTF8(actual^.destinatario)),
                       3, PChar(SanearUTF8(actual^.asunto)),
                       -1);
    
    Inc(contador);
    actual := actual^.siguiente;
  end;
  
  LiberarListaEliminadosUI(lista);
  
  // Actualizar información
  if LabelInfo <> nil then
  begin
    if contador > 0 then
      gtk_label_set_text(GTK_LABEL(LabelInfo), PChar('Total eliminados: ' + IntToStr(contador)))
    else
      gtk_label_set_text(GTK_LABEL(LabelInfo), 'Papelera vacía');
  end;
  
  WriteLn('🗑️ Correos eliminados cargados: ', contador);
end;

procedure OnSeleccionarEliminado(widget: PGtkWidget; data: gpointer); cdecl;
var
  selection: PGtkTreeSelection;
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  idStr: PChar;
  correoID: Integer;
  correo: pila2.PCorreo;
  buffer: PGtkTextBuffer;
  textoDetalle: String;
begin
  if ListaEliminados = nil then Exit;
  
  selection := gtk_tree_view_get_selection(PGtkTreeView(ListaEliminados));
  if selection = nil then Exit;
  
  if gtk_tree_selection_get_selected(selection, @model, @iter) then
  begin
    idStr := nil;
    gtk_tree_model_get(model, @iter, 0, @idStr, -1);
    
    if idStr <> nil then
    begin
      correoID := StrToIntDef(StrPas(idStr), 0);
      g_free(idStr);
      
      if correoID <> 0 then
      begin
        correo := BuscarCorreo(GPapelera^, correoID);
        if correo <> nil then
        begin
          EliminadoSeleccionado := correoID;
          
          textoDetalle := '🗑️ CORREO ELIMINADO' + #13#10 +
                          '====================' + #13#10 + #13#10 +
                          'ID: ' + IntToStr(correo^.id) + #13#10 +
                          'De: ' + SanearUTF8(correo^.remitente) + #13#10 +
                          'Para: ' + SanearUTF8(correo^.destinatario) + #13#10 + #13#10 +
                          'ASUNTO:' + #13#10 +
                          SanearUTF8(correo^.asunto) + #13#10 + #13#10 +
                          'MENSAJE:' + #13#10 +
                          '--------' + #13#10 +
                          SanearUTF8(correo^.mensaje);
          
          buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
          gtk_text_buffer_set_text(buffer, PChar(textoDetalle), -1);
          
          WriteLn('🗑️ Correo eliminado seleccionado ID: ', correoID);
        end;
      end;
    end;
  end
  else
  begin
    EliminadoSeleccionado := 0; // Reset selection
    if TextViewDetalle <> nil then
    begin
      buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
      gtk_text_buffer_set_text(buffer, 'Selecciona un correo eliminado para ver detalles', -1);
    end;
  end;
end;

procedure OnVaciarPapelera(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if GPapelera <> nil then
  begin
    LiberarPila(GPapelera^);
    WriteLn('🗑️ Papelera vaciada completamente');
    CargarEliminadosEnLista;
    
    if TextViewDetalle <> nil then
      gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), 
                               'Papelera vaciada', -1);
  end;
end;

procedure OnMostrarPila(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('📚 Estructura de la Pila (Papelera):');
  WriteLn('====================================');
  if (GPapelera <> nil) and not EstaVacia(GPapelera^) then
    MostrarPila(GPapelera^)
  else
    WriteLn('La pila está vacía');
  WriteLn('====================================');
end;

procedure OnActualizarPapelera(widget: PGtkWidget; data: gpointer); cdecl;
begin
  CargarEliminadosEnLista;
  
  if TextViewDetalle <> nil then
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), '', -1);
end;

procedure OnCerrarPapelera(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(PapeleraWindow) then
    gtk_widget_destroy(PapeleraWindow);
end;

function OnDeleteEventPapelera(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando papelera...');
  if Assigned(PapeleraWindow) then
    gtk_widget_destroy(PapeleraWindow);
  Result := True;
end;

procedure EliminarCorreoDeBandeja(correoID: Integer; const remitente, destinatario, asunto, mensaje: String; var papelera: TPila);
begin
  // Agregar a la pila de eliminados
  Apilar(papelera, correoID, remitente, destinatario, asunto, mensaje);
  WriteLn('🗑️ Correo movido a papelera ID: ', correoID);
end;

procedure MostrarPapelera(const emailUsuario: String; var papelera: TPila);
var
  hpaned, vboxIzq, vboxDer, scrolledLista, scrolledDetalle: PGtkWidget;
  lblTitulo, lblDetalle: PGtkWidget;
  btnVaciar, btnActualizar, btnMostrarPila, btnCerrar, btnBox: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
begin
  GEmailUsuario := emailUsuario;
  GPapelera := @papelera;
  EliminadoSeleccionado := 0;
  
  WriteLn('🗑️ Abriendo papelera para: ', emailUsuario);
  
  if Assigned(PapeleraWindow) then
    gtk_widget_destroy(PapeleraWindow);
  
  PapeleraWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(PapeleraWindow), PChar('🗑️ Papelera - ' + emailUsuario));
  gtk_window_set_default_size(GTK_WINDOW(PapeleraWindow), 1200, 700);
  g_signal_connect(PapeleraWindow, 'delete-event', G_CALLBACK(@OnDeleteEventPapelera), nil);
  
  hpaned := gtk_hpaned_new();
  gtk_container_add(GTK_CONTAINER(PapeleraWindow), hpaned);
  
  // Panel izquierdo - Lista de eliminados
  vboxIzq := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxIzq), 10);
  gtk_paned_add1(GTK_PANED(hpaned), vboxIzq);
  
  lblTitulo := gtk_label_new('🗑️ Correos Eliminados (Pila)');
  gtk_box_pack_start(GTK_BOX(vboxIzq), lblTitulo, False, False, 0);
  
  scrolledLista := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledLista), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxIzq), scrolledLista, True, True, 0);
  
  store := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  ListaEliminados := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista), ListaEliminados);
  
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('ID', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 60);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaEliminados), column);
  
  column := gtk_tree_view_column_new_with_attributes('De', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaEliminados), column);
  
  column := gtk_tree_view_column_new_with_attributes('Para', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaEliminados), column);
  
  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 250);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaEliminados), column);
  
  g_signal_connect(gtk_tree_view_get_selection(PGtkTreeView(ListaEliminados)), 
                   'changed', G_CALLBACK(@OnSeleccionarEliminado), nil);
  
  // Botones de acción
  btnBox := gtk_hbox_new(True, 5);
  gtk_box_pack_start(GTK_BOX(vboxIzq), btnBox, False, False, 0);
  
  btnActualizar := gtk_button_new_with_label('🔄 Actualizar');
  g_signal_connect(btnActualizar, 'clicked', G_CALLBACK(@OnActualizarPapelera), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnActualizar, True, True, 0);
  
  btnVaciar := gtk_button_new_with_label('🗑️ Vaciar');
  g_signal_connect(btnVaciar, 'clicked', G_CALLBACK(@OnVaciarPapelera), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnVaciar, True, True, 0);
  
  btnMostrarPila := gtk_button_new_with_label('📚 Ver Pila');
  g_signal_connect(btnMostrarPila, 'clicked', G_CALLBACK(@OnMostrarPila), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnMostrarPila, True, True, 0);
  
  btnCerrar := gtk_button_new_with_label('❌ Cerrar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarPapelera), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCerrar, True, True, 0);
  
  LabelInfo := gtk_label_new('');
  gtk_box_pack_start(GTK_BOX(vboxIzq), LabelInfo, False, False, 0);
  
  // Panel derecho - Detalle del eliminado
  vboxDer := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxDer), 10);
  gtk_paned_add2(GTK_PANED(hpaned), vboxDer);
  
  lblDetalle := gtk_label_new('Detalle del correo eliminado:');
  gtk_box_pack_start(GTK_BOX(vboxDer), lblDetalle, False, False, 0);
  
  scrolledDetalle := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledDetalle), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxDer), scrolledDetalle, True, True, 0);
  
  TextViewDetalle := gtk_text_view_new();
  gtk_text_view_set_editable(PGtkTextView(TextViewDetalle), False);
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewDetalle), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledDetalle), TextViewDetalle);
  
  // Mensaje inicial
  if TextViewDetalle <> nil then
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), 
      'Correos eliminados aparecerán aquí.' + #13#10 + #13#10 + 
      'Los correos se eliminan de la bandeja' + #13#10 +
      'y se almacenan en esta pila (LIFO).', -1);
  
  CargarEliminadosEnLista;
  gtk_widget_show_all(PapeleraWindow);
end;

end.
