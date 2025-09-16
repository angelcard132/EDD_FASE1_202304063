program BST_JSON;

{$mode objfpc}{$H+}

uses
  SysUtils, fpjson, jsonparser, Classes;

type
  PNode = ^TNode;
  TNode = record
    id: Integer;
    first_name: string;
    last_name: string;
    email: string;
    left, right: PNode;
  end;

var
  Root: PNode = nil;

procedure InsertNode(var Root: PNode; id: Integer; fn, ln, em: string);
begin
  if Root = nil then
  begin
    New(Root);
    Root^.id := id;
    Root^.first_name := fn;
    Root^.last_name := ln;
    Root^.email := em;
    Root^.left := nil;
    Root^.right := nil;
    Writeln('[DEBUG] Nodo insertado en el árbol -> ID: ', id, ', Nombre: ', fn, ' ', ln);
  end
  else if id < Root^.id then
  begin
    Writeln('[DEBUG] ID ', id, ' es menor que ', Root^.id, ' -> Insertar a la izquierda');
    InsertNode(Root^.left, id, fn, ln, em);
  end
  else
  begin
    Writeln('[DEBUG] ID ', id, ' es mayor o igual que ', Root^.id, ' -> Insertar a la derecha');
    InsertNode(Root^.right, id, fn, ln, em);
  end;
end;

procedure GenerateDOT(Root: PNode; var F: Text);
begin
  if Root = nil then Exit;

  if Root^.left <> nil then
  begin
    Writeln(F, '  "', Root^.id, ' ', Root^.first_name, '" -> "', Root^.left^.id, ' ', Root^.left^.first_name, '";');
    GenerateDOT(Root^.left, F);
  end;

  if Root^.right <> nil then
  begin
    Writeln(F, '  "', Root^.id, ' ', Root^.first_name, '" -> "', Root^.right^.id, ' ', Root^.right^.first_name, '";');
    GenerateDOT(Root^.right, F);
  end;
end;

procedure ExportToDOT(Root: PNode; const FileName: string);
var
  F: Text;
begin
  AssignFile(F, FileName);
  Rewrite(F);
  Writeln(F, 'digraph BST {');
  Writeln(F, '  node [shape=circle, style=filled, color=lightblue];');
  GenerateDOT(Root, F);
  Writeln(F, '}');
  CloseFile(F);
  Writeln('[DEBUG] Archivo DOT generado: ', FileName);
end;

procedure LoadJSON(const FileName: string);
var
  JSONData: TJSONData;
  JSONArray: TJSONArray;
  Obj: TJSONObject;
  Parser: TJSONParser;
  FS: TFileStream;
  i: Integer;
begin
  Writeln('[DEBUG] Cargando archivo JSON: ', FileName);
  FS := TFileStream.Create(FileName, fmOpenRead);
  try
    Parser := TJSONParser.Create(FS);
    try
      JSONData := Parser.Parse;
      JSONArray := TJSONArray(JSONData);

      Writeln('[DEBUG] Cantidad de registros en JSON: ', JSONArray.Count);

      for i := 0 to JSONArray.Count - 1 do
      begin
        Obj := JSONArray.Objects[i];
        Writeln('[DEBUG] Leyendo registro -> ID: ', Obj.Integers['id']);
        InsertNode(Root,
                   Obj.Integers['id'],
                   Obj.Strings['first_name'],
                   Obj.Strings['last_name'],
                   Obj.Strings['email']);
      end;

    finally
      Parser.Free;
    end;
  finally
    FS.Free;
  end;
end;

begin
  try
    LoadJSON('datos.json');
    Writeln('[DEBUG] Finalizó la carga de datos en el BST.');
    ExportToDOT(Root, 'bst.dot');
    Writeln('[DEBUG] Proceso completado. Ejecuta: dot -Tpng bst.dot -o bst.png');
  except
    on E: Exception do
      Writeln('Error: ', E.Message);
  end;
end.
