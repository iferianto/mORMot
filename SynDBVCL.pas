/// DB VCL read/only dataset from SynDB data access
// - this unit is a part of the freeware Synopse framework,
// licensed under a MPL/GPL/LGPL tri-license; version 1.18
unit SynDBVCL;

{
    This file is part of Synopse framework.

    Synopse framework. Copyright (C) 2014 Arnaud Bouchez
      Synopse Informatique - http://synopse.info

  *** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
  for the specific language governing rights and limitations under the License.

  The Original Code is Synopse mORMot framework.

  The Initial Developer of the Original Code is Arnaud Bouchez.

  Portions created by the Initial Developer are Copyright (C) 2014
  the Initial Developer. All Rights Reserved.

  Contributor(s):
  - Alfred Glaenzer (alf)

  Alternatively, the contents of this file may be used under the terms of
  either the GNU General Public License Version 2 or later (the "GPL"), or
  the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
  in which case the provisions of the GPL or the LGPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of either the GPL or the LGPL, and not to allow others to
  use your version of this file under the terms of the MPL, indicate your
  decision by deleting the provisions above and replace them with the notice
  and other provisions required by the GPL or the LGPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the MPL, the GPL or the LGPL.

  ***** END LICENSE BLOCK *****

  Version 1.17
  - first public release, corresponding to Synopse mORMot Framework 1.17

  Version 1.18
  - BREAKING CHANGE: QueryToDataSet() and StatementToDataSet() renamed
    as overloaded functions ToDataSet()
  - now uses read/only TSynVirtualDataSet class for much faster process
    and lower resource use - see SynDBMidasVCL.pas unit if you need
  	a TClientDataset writable (but slower) instance


}

{$I Synopse.inc} // define HASINLINE USETYPEINFO CPU32 CPU64 OWNNORMTOUPPER

interface

uses
  {$ifdef ISDELPHIXE2}System.SysUtils,{$else}SysUtils,{$endif}
  Classes,
  Contnrs,
  SynCommons,
  SynDB,
  DB,
  SynVirtualDataSet;

type
  /// read-only virtual TDataSet able to access a binary buffer as returned
  // by TSQLStatement.FetchAllToBinary method
  TSynBinaryDataSet = class(TSynVirtualDataSet)
  protected
    fData: RawByteString;
    fDataAccess: TSQLDBProxyStatementRandomAccess;
    fTemp64: Int64;
    procedure InternalInitFieldDefs; override;
    function GetRecordCount: Integer; override;
    function GetRowFieldData(Field: TField; RowIndex: integer;
      out ResultLen: Integer; OnlyCheckNull: boolean): Pointer; override;
  public
    /// initialize the virtual TDataSet from a FetchAllToBinary() buffer
    constructor Create(Owner: TComponent; const BinaryData: RawByteString;
      DataRowPosition: PCardinalDynArray=nil); reintroduce;
    /// finalize the class instance
    destructor Destroy; override;
    /// read-only access to the internal binary buffer
    property Data: RawByteString read fData;
    /// read-only access to the internal SynDB data
    property DataAccess: TSQLDBProxyStatementRandomAccess read fDataAccess;
  end;

  /// read-only virtual TDataSet able to access a TSQLStatement result set
  TSynSQLStatementDataSet = class(TSynBinaryDataSet)
  protected
  public
    /// initialize the virtual TDataSet from a SynDB TSQLDBStatement
    // - the supplied ISQLDBRows instance can safely be freed by caller
    constructor Create(Owner: TComponent; Statement: TSQLDBStatement;
      MaxRowCount: cardinal=0); reintroduce;
  end;


/// fetch a SynDB's TQuery result into a VCL DataSet
// - if aMaxRowCount>0, will return up to the specified number of rows
// - current implementation will return a TSynSQLStatementDataSet instance,
// using an optimized internal binary buffer: the supplied TQuery can be released
// - if you need a writable TDataSet, you can use the slower ToClientDataSet()
// function as defined in SynDBMidasVCL.pas
function ToDataSet(aOwner: TComponent; aStatement: SynDB.TQuery;
  aMaxRowCount: integer=0): TSynSQLStatementDataSet; overload;

/// fetch a SynDB's TSQLDBStatement result into a VCL DataSet
// - just a wrapper around TSynSQLStatementDataSet.Create + Open
// - if aMaxRowCount>0, will return up to the specified number of rows
// - current implementation will return a TSynSQLStatementDataSet instance, using
// an optimized internal binary buffer: the supplied statement can be released
// - if you need a writable TDataSet, you can use the slower ToClientDataSet()
// function as defined in SynDBMidasVCL.pas
function ToDataSet(aOwner: TComponent; aStatement: TSQLDBStatement;
  aMaxRowCount: integer=0): TSynSQLStatementDataSet; overload;

/// fetch a SynDB's TSQLDBStatement.FetchAllToBinary buffer into a VCL DataSet
// - just a wrapper around TSynBinaryDataSet.Create + Open
// - if you need a writable TDataSet, you can use the slower ToClientDataSet()
// function as defined in SynDBMidasVCL.pas
function BinaryToDataSet(aOwner: TComponent;
  const aBinaryData: RawByteString): TSynBinaryDataSet;


implementation


function ToDataSet(aOwner: TComponent; aStatement: SynDB.TQuery;
  aMaxRowCount: integer): TSynSQLStatementDataSet;
begin
  if aStatement=nil then
    result := nil else
    result := ToDataSet(aOwner,
      aStatement.PreparedSQLDBStatement.Instance,aMaxRowCount);
end;

function ToDataSet(aOwner: TComponent; aStatement: TSQLDBStatement;
  aMaxRowCount: integer): TSynSQLStatementDataSet;
begin
  result := TSynSQLStatementDataSet.Create(aOwner,aStatement,aMaxRowCount);
  result.Open;
end;

function BinaryToDataSet(aOwner: TComponent; const aBinaryData: RawByteString): TSynBinaryDataSet;
begin
  result := TSynBinaryDataSet.Create(aOwner,aBinaryData);
  result.Open;
end;


{ TSynBinaryDataSet }

constructor TSynBinaryDataSet.Create(Owner: TComponent; const BinaryData: RawByteString;
  DataRowPosition: PCardinalDynArray);
begin
  inherited Create(Owner);
  fData := BinaryData;
  fDataAccess := TSQLDBProxyStatementRandomAccess.Create(
    pointer(fData),length(fData),DataRowPosition);
end;

destructor TSynBinaryDataSet.Destroy;
begin
  fDataAccess.Free;
  inherited;
end;

function TSynBinaryDataSet.GetRecordCount: Integer;
begin
  result := fDataAccess.DataRowCount;
end;

procedure TSynBinaryDataSet.InternalInitFieldDefs;
var F: integer;
    DBType: TFieldType;
begin
  FieldDefs.Clear;
  if fDataAccess=nil then
    exit;
  for F := 0 to fDataAccess.ColumnCount-1 do
    with fDataAccess.Columns[F] do begin
    case ColumnType of
    SynCommons.ftInt64: DBType := ftLargeint;
    SynCommons.ftDate:  DBType := ftDateTime;
    SynCommons.ftUTF8:  DBType := ftWideString; // means UnicodeString for Delphi 2009+
    SynCommons.ftBlob:  DBType := ftBlob;
    SynCommons.ftDouble, SynCommons.ftCurrency: DBType := ftFloat;
    else raise EDatabaseError.CreateFmt('GetFieldData ColumnType=%d',[ord(ColumnType)]);
    end;
    FieldDefs.Add(UTF8ToString(ColumnName),DBType,ColumnDataSize);
  end;
end;

function TSynBinaryDataSet.GetRowFieldData(Field: TField;
  RowIndex: integer; out ResultLen: Integer; OnlyCheckNull: boolean): Pointer;
var F: integer;
begin
  result := nil;
  F := Field.Index;
  if not fDataAccess.GotoRow(RowIndex) then
    exit;
  result := fDataAccess.ColumnData(F);
  if (result<>nil) and not OnlyCheckNull then
    case fDataAccess.Columns[F].ColumnType of
    SynCommons.ftInt64: begin
      fTemp64 := FromVarInt64(PByte(result));
      result := @fTemp64;
    end;
    SynCommons.ftCurrency: begin // ftFloat expects a DOUBLE value
      PDouble(@fTemp64)^ := PCurrency(result)^;
      result := @fTemp64;
    end;
    SynCommons.ftUTF8, SynCommons.ftBlob:
      resultLen := FromVarUInt32(PByte(result));
    end; // other ColumnTypes are already in the expected format
end;


{ TSynSQLStatementDataSet }

constructor TSynSQLStatementDataSet.Create(Owner: TComponent;
  Statement: TSQLDBStatement; MaxRowCount: cardinal=0);
var DataStream: TRawByteStringStream;
    DataRowPosition: TCardinalDynArray;
begin
  DataStream := TRawByteStringStream.Create;
  try
    Statement.FetchAllToBinary(DataStream,MaxRowCount,@DataRowPosition);
    inherited Create(Owner,DataStream.DataString,@DataRowPosition);
  finally
    DataStream.Free;
  end;
end;


end.
