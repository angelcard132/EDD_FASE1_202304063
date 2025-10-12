unit favoritos;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  arbol_b, cola2, json_loader;

procedure MostrarGestorFavoritos(const emailUsuario: String; var favoritos: PNodoB; var programados: TCola);

implementation

type
  PFavoritoUI = ^TFavoritoUI;
  TFavoritoUI = record
    id: Integer;
    remitente: String;
    destinatario: String;
    asunto: String;
    mensaje: String;
    siguiente: PFavoritoUI;
  end;

var
  GEmailUsuario: String;
  GFavoritos: ^PNodoB;
  GProgramados: ^TCola;
  
  FavoritosWindow: PGtkWidget;
  ListaFavoritos: PGtkWidget;
  TextViewDetalle: PGtkWidget;
  LabelInfo: PGtkWidget;
  
  FavoritoSeleccionado: Integer;

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

procedure LiberarListaFavoritosUI(var lista: PFavoritoUI);
var
  actual, temp: PFavoritoUI;
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

procedure AgregarFavoritoALista(var lista: PFavoritoUI; const correo: TCorreoB);
var
  nuevo: PFavoritoUI;
begin
  New(nuevo);
  nuevo^.id := correo.id;
  nuevo^.remitente := correo.remitente;
  nuevo^.destinatario := correo.destinatario;
  nuevo^.asunto := correo.asunto;
  nuevo^.mensaje := correo.mensaje;
  nuevo^.siguiente := lista;
  lista := nuevo;
end;

// Callback para recorrido del árbol B
procedure CallbackRecolectarFavoritos(correo: TCorreoB; data: Pointer);
var
  lista: ^PFavoritoUI;
begin
  if data <> nil then
  begin
    lista := PPointer(data)^;
    // Filtrar por destinatario (correos recibidos) o remitente (correos enviados)
    if (correo.destinatario = GEmailUsuario) or (correo.remitente = GEmailUsuario) then
      AgregarFavoritoALista(lista^, correo);
  end;
end;

function ObtenerFavoritosDelUsuario: PFavoritoUI;
var
  lista: PFavoritoUI;
  pLista: Pointer;
begin
  lista := nil;
  pLista := @lista;
  
  if (GFavoritos <> nil) and (GFavoritos^ <> nil) then
    RecorridoInOrden(GFavoritos^, @CallbackRecolectarFavoritos, @pLista);
  
  Result := lista;
end;

procedure CargarFavoritosEnLista;
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  lista, actual: PFavoritoUI;
  idStr: String;
  contador: Integer;
begin
  if ListaFavoritos = nil then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaFavoritos)));
  if store = nil then Exit;
  
  gtk_list_store_clear(store);
  
  lista := ObtenerFavoritosDelUsuario;
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
  
  LiberarListaFavoritosUI(lista);
  
  // Actualizar información con mensaje más claro
  if LabelInfo <> nil then
  begin
    if contador > 0 then
      gtk_label_set_text(GTK_LABEL(LabelInfo), PChar('Total favoritos: ' + IntToStr(contador)))
    else
      gtk_label_set_text(GTK_LABEL(LabelInfo), 'No hay favoritos. Agrega correos desde la bandeja de entrada.');
  end;
  
  WriteLn('📊 Favoritos cargados: ', contador);
end;

procedure OnSeleccionarFavorito(widget: PGtkWidget; data: gpointer); cdecl;
var
  selection: PGtkTreeSelection;
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  idStr: PChar;
  correoID: Integer;
  correo: PCorreoB;
  buffer: PGtkTextBuffer;
  textoDetalle: String;
begin
  if ListaFavoritos = nil then Exit;
  
  selection := gtk_tree_view_get_selection(PGtkTreeView(ListaFavoritos));
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
        correo := Buscar(GFavoritos^, correoID);
        if correo <> nil then
        begin
          FavoritoSeleccionado := correoID;
          
          textoDetalle := '⭐ CORREO FAVORITO' + #13#10 +
                          '==================' + #13#10 + #13#10 +
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
          
          WriteLn('⭐ Favorito seleccionado ID: ', correoID);
        end;
      end;
    end;
  end
  else
  begin
    if TextViewDetalle <> nil then
    begin
      buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
      gtk_text_buffer_set_text(buffer, 'Selecciona un favorito para ver detalles', -1);
    end;
  end;
end;

procedure OnEliminarFavorito(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if FavoritoSeleccionado > 0 then
  begin
    if Eliminar(GFavoritos^, FavoritoSeleccionado) then
    begin
      WriteLn('🗑️ Favorito eliminado ID: ', FavoritoSeleccionado);
      CargarFavoritosEnLista;
      
      // Limpiar detalle
      if TextViewDetalle <> nil then
        gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), 
                                 'Favorito eliminado', -1);
      
      FavoritoSeleccionado := 0;
    end
    else
      WriteLn('❌ Error al eliminar favorito');
  end
  else
    WriteLn('⚠️ Selecciona un favorito para eliminar');
end;

procedure OnMostrarArbolB(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('🌳 Estructura del Árbol B de Favoritos:');
  WriteLn('=======================================');
  if GFavoritos^ <> nil then
    Mostrar(GFavoritos^, 0)
  else
    WriteLn('El árbol está vacío');
  WriteLn('=======================================');
end;

procedure OnActualizarFavoritos(widget: PGtkWidget; data: gpointer); cdecl;
begin
  CargarFavoritosEnLista;
  
  // Limpiar detalle
  if TextViewDetalle <> nil then
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), '', -1);
end;

procedure OnCerrarFavoritos(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(FavoritosWindow) then
    gtk_widget_destroy(FavoritosWindow);
end;

function OnDeleteEventFavoritos(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando gestor de favoritos...');
  if Assigned(FavoritosWindow) then
    gtk_widget_destroy(FavoritosWindow);
  Result := True;
end;

procedure MostrarGestorFavoritos(const emailUsuario: String; var favoritos: PNodoB; var programados: TCola);
var
  hpaned, vboxIzq, vboxDer, scrolledLista, scrolledDetalle: PGtkWidget;
  lblTitulo, lblDetalle: PGtkWidget;
  btnEliminar, btnActualizar, btnMostrarArbol, btnCerrar, btnBox: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
begin
  GEmailUsuario := emailUsuario;
  GFavoritos := @favoritos;
  GProgramados := @programados;
  FavoritoSeleccionado := 0;
  
  WriteLn('⭐ Abriendo gestor de favoritos para: ', emailUsuario);
  
  if Assigned(FavoritosWindow) then
    gtk_widget_destroy(FavoritosWindow);
  
  FavoritosWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(FavoritosWindow), PChar('⭐ Gestión de Favoritos - ' + emailUsuario));
  gtk_window_set_default_size(GTK_WINDOW(FavoritosWindow), 1200, 700);
  g_signal_connect(FavoritosWindow, 'delete-event', G_CALLBACK(@OnDeleteEventFavoritos), nil);
  
  hpaned := gtk_hpaned_new();
  gtk_container_add(GTK_CONTAINER(FavoritosWindow), hpaned);
  
  // Panel izquierdo - Lista de favoritos
  vboxIzq := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxIzq), 10);
  gtk_paned_add1(GTK_PANED(hpaned), vboxIzq);
  
  lblTitulo := gtk_label_new('⭐ Correos Favoritos (Árbol B)');
  gtk_box_pack_start(GTK_BOX(vboxIzq), lblTitulo, False, False, 0);
  
  scrolledLista := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledLista), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxIzq), scrolledLista, True, True, 0);
  
  store := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  ListaFavoritos := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista), ListaFavoritos);
  
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('ID', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 60);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaFavoritos), column);
  
  column := gtk_tree_view_column_new_with_attributes('De', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaFavoritos), column);
  
  column := gtk_tree_view_column_new_with_attributes('Para', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaFavoritos), column);
  
  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 250);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaFavoritos), column);
  
  g_signal_connect(gtk_tree_view_get_selection(PGtkTreeView(ListaFavoritos)), 
                   'changed', G_CALLBACK(@OnSeleccionarFavorito), nil);
  
  // Botones de acción
  btnBox := gtk_hbox_new(True, 5);
  gtk_box_pack_start(GTK_BOX(vboxIzq), btnBox, False, False, 0);
  
  btnActualizar := gtk_button_new_with_label('🔄 Actualizar');
  g_signal_connect(btnActualizar, 'clicked', G_CALLBACK(@OnActualizarFavoritos), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnActualizar, True, True, 0);
  
  btnEliminar := gtk_button_new_with_label('🗑️ Eliminar');
  g_signal_connect(btnEliminar, 'clicked', G_CALLBACK(@OnEliminarFavorito), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnEliminar, True, True, 0);
  
  btnMostrarArbol := gtk_button_new_with_label('🌳 Ver Árbol');
  g_signal_connect(btnMostrarArbol, 'clicked', G_CALLBACK(@OnMostrarArbolB), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnMostrarArbol, True, True, 0);
  
  btnCerrar := gtk_button_new_with_label('❌ Cerrar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarFavoritos), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCerrar, True, True, 0);
  
  LabelInfo := gtk_label_new('');
  gtk_box_pack_start(GTK_BOX(vboxIzq), LabelInfo, False, False, 0);
  
  // Panel derecho - Detalle del favorito
  vboxDer := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxDer), 10);
  gtk_paned_add2(GTK_PANED(hpaned), vboxDer);
  
  lblDetalle := gtk_label_new('Detalle del favorito:');
  gtk_box_pack_start(GTK_BOX(vboxDer), lblDetalle, False, False, 0);
  
  scrolledDetalle := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledDetalle), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxDer), scrolledDetalle, True, True, 0);
  
  TextViewDetalle := gtk_text_view_new();
  gtk_text_view_set_editable(PGtkTextView(TextViewDetalle), False);
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewDetalle), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledDetalle), TextViewDetalle);
  
  // Mostrar mensaje inicial si no hay favoritos
  if TextViewDetalle <> nil then
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), 
      'Los favoritos aparecerán aquí.' + #13#10 + #13#10 + 
      'Para agregar un correo a favoritos:' + #13#10 +
      '1. Ve a tu bandeja de entrada' + #13#10 +
      '2. Selecciona un correo' + #13#10 +
      '3. Haz clic en "⭐ A Favoritos"', -1);
  
  CargarFavoritosEnLista;
  gtk_widget_show_all(FavoritosWindow);
end;

end.
