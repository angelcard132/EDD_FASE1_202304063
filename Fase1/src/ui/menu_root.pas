unit menu_root;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, SysUtils, graphviz, comunidadesui;

procedure MostrarMenuRoot;

implementation

procedure on_carga_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('Carga masiva JSON seleccionada');
end;

procedure on_reporte_usuarios_clicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  carpeta: String;
  comando: String;
  exito: Boolean;
begin
  WriteLn('📊 Generando reporte de usuarios...');
  
  carpeta := '../graficos/';
  
  // Crear carpeta si no existe
  if not DirectoryExists(carpeta) then
    ForceDirectories(carpeta);
  
  // Generar archivo .dot de usuarios
  GenerarGraficoUsuarios(carpeta + 'usuarios.dot');
  
  // Verificar si Graphviz está disponible
  if ComprobarGraphviz then
  begin
    WriteLn('🖼️ Generando imagen PNG de usuarios...');
    
    {$IFDEF WINDOWS}
    comando := 'dot -Tpng "' + carpeta + 'usuarios.dot" -o "' + carpeta + 'usuarios.png"';
    {$ELSE}
    comando := 'dot -Tpng "' + carpeta + 'usuarios.dot" -o "' + carpeta + 'usuarios.png"';
    {$ENDIF}
    
    exito := EjecutarComando(comando);
    
    if exito then
    begin
      WriteLn('✅ Reporte de usuarios generado exitosamente');
      WriteLn('📁 Archivos disponibles:');
      WriteLn('   - ', carpeta, 'usuarios.dot');
      WriteLn('   - ', carpeta, 'usuarios.png');
    end
    else
    begin
      WriteLn('❌ Error generando imagen PNG');
      WriteLn('📄 Archivo .dot generado: ', carpeta, 'usuarios.dot');
    end;
  end
  else
  begin
    WriteLn('⚠️ Graphviz no disponible - solo se generó el archivo .dot');
    WriteLn('📄 Archivo disponible: ', carpeta, 'usuarios.dot');
  end;
  
  WriteLn('🎯 Reporte de usuarios completado');
end;

procedure on_reporte_relaciones_clicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  carpeta: String;
  comando: String;
  exito: Boolean;
begin
  WriteLn('📊 Generando reporte de relaciones (matriz dispersa)...');
  
  carpeta := '../graficos/';
  
  // Crear carpeta si no existe
  if not DirectoryExists(carpeta) then
    ForceDirectories(carpeta);
  
  // Generar archivo .dot de matriz dispersa
  GenerarGraficoMatrizDispersa(carpeta + 'matriz.dot');
  
  // Verificar si Graphviz está disponible
  if ComprobarGraphviz then
  begin
    WriteLn('🖼️ Generando imagen PNG de matriz dispersa...');
    
    {$IFDEF WINDOWS}
    comando := 'dot -Tpng "' + carpeta + 'matriz.dot" -o "' + carpeta + 'matriz.png"';
    {$ELSE}
    comando := 'dot -Tpng "' + carpeta + 'matriz.dot" -o "' + carpeta + 'matriz.png"';
    {$ENDIF}
    
    exito := EjecutarComando(comando);
    
    if exito then
    begin
      WriteLn('✅ Reporte de relaciones generado exitosamente');
      WriteLn('📁 Archivos disponibles:');
      WriteLn('   - ', carpeta, 'matriz.dot');
      WriteLn('   - ', carpeta, 'matriz.png');
    end
    else
    begin
      WriteLn('❌ Error generando imagen PNG');
      WriteLn('📄 Archivo .dot generado: ', carpeta, 'matriz.dot');
    end;
  end
  else
  begin
    WriteLn('⚠️ Graphviz no disponible - solo se generó el archivo .dot');
    WriteLn('📄 Archivo disponible: ', carpeta, 'matriz.dot');
  end;
  
  WriteLn('🎯 Reporte de relaciones completado');
end;

procedure on_reporte_comunidades_clicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  carpeta: String;
  comando: String;
  exito: Boolean;
begin
  WriteLn('📊 Generando reporte de comunidades (lista de listas)...');
  
  carpeta := '../graficos/';
  
  // Crear carpeta si no existe
  if not DirectoryExists(carpeta) then
    ForceDirectories(carpeta);
  
  // Generar archivo .dot de comunidades
  GenerarGraficoComunidades(carpeta + 'comunidades.dot');
  
  // Verificar si Graphviz está disponible
  if ComprobarGraphviz then
  begin
    WriteLn('🖼️ Generando imagen PNG de comunidades...');
    
    {$IFDEF WINDOWS}
    comando := 'dot -Tpng "' + carpeta + 'comunidades.dot" -o "' + carpeta + 'comunidades.png"';
    {$ELSE}
    comando := 'dot -Tpng "' + carpeta + 'comunidades.dot" -o "' + carpeta + 'comunidades.png"';
    {$ENDIF}
    
    exito := EjecutarComando(comando);
    
    if exito then
    begin
      WriteLn('✅ Reporte de comunidades generado exitosamente');
      WriteLn('📁 Archivos disponibles:');
      WriteLn('   - ', carpeta, 'comunidades.dot');
      WriteLn('   - ', carpeta, 'comunidades.png');
    end
    else
    begin
      WriteLn('❌ Error generando imagen PNG');
      WriteLn('📄 Archivo .dot generado: ', carpeta, 'comunidades.dot');
    end;
  end
  else
  begin
    WriteLn('⚠️ Graphviz no disponible - solo se generó el archivo .dot');
    WriteLn('📄 Archivo disponible: ', carpeta, 'comunidades.dot');
  end;
  
  WriteLn('🎯 Reporte de comunidades completado');
end;

procedure on_comunidades_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarComunidades;
end;

procedure on_todos_reportes_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  GenerarTodosLosGraficos;
end;

procedure MostrarMenuRoot;
var
  window: PGtkWidget;
  vbox: PGtkWidget;
  btnCarga, btnRepUsuarios, btnRepRelaciones, btnRepComunidades, btnComunidades, btnRepTodos: PGtkWidget;
begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'EDDMail - Root Menu');
  gtk_window_set_default_size(GTK_WINDOW(window), 320, 350);

  vbox := gtk_vbox_new(FALSE, 8);
  gtk_container_add(GTK_CONTAINER(window), vbox);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 10);

  btnCarga := gtk_button_new_with_label('📁 Carga Masiva JSON');
  g_signal_connect(btnCarga, 'clicked', G_CALLBACK(@on_carga_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnCarga, FALSE, FALSE, 0);

  btnRepUsuarios := gtk_button_new_with_label('📊 Reporte de Usuarios');
  g_signal_connect(btnRepUsuarios, 'clicked', G_CALLBACK(@on_reporte_usuarios_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRepUsuarios, FALSE, FALSE, 0);

  btnRepRelaciones := gtk_button_new_with_label('🔗 Reporte de Relaciones');
  g_signal_connect(btnRepRelaciones, 'clicked', G_CALLBACK(@on_reporte_relaciones_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRepRelaciones, FALSE, FALSE, 0);

  btnRepComunidades := gtk_button_new_with_label('🏘️ Reporte de Comunidades');
  g_signal_connect(btnRepComunidades, 'clicked', G_CALLBACK(@on_reporte_comunidades_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRepComunidades, FALSE, FALSE, 0);

  btnComunidades := gtk_button_new_with_label('🏢 Gestión de Comunidades');
  g_signal_connect(btnComunidades, 'clicked', G_CALLBACK(@on_comunidades_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnComunidades, FALSE, FALSE, 0);

  btnRepTodos := gtk_button_new_with_label('📈 Generar Todos los Reportes');
  g_signal_connect(btnRepTodos, 'clicked', G_CALLBACK(@on_todos_reportes_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRepTodos, FALSE, FALSE, 0);

  gtk_widget_show_all(window);
end;

end.
  gtk_box_pack_start(GTK_BOX(vbox), btnRepTodos, FALSE, FALSE, 0);

  gtk_widget_show_all(window);
end;

end.
