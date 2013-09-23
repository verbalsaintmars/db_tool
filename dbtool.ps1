<#
https://wiki.eng.vmware.com/CPD/SRM/Proposals/DbToolDesign
https://wiki.eng.vmware.com/User:Mkolechkin/SRM/DB
#>

[CmdletBinding(
   DefaultParameterSetName = 'TOOL_TYPE')]
   param(
<#
      [Parameter(
         Mandatory=$true,
         ParameterSetName = 'ODBC_CONNECTION')]
      [string]$DSN_Primary,

      [Parameter(
         Mandatory=$true,
         ParameterSetName = 'ODBC_CONNECTION')]
      [string]$DSN_Secondary,

      [Parameter(
         Mandatory=$true,
         ParameterSetName = 'ODBC_CONNECTION')]
      [string]$UID_Primary,

      [Parameter(
         Mandatory=$true,
         ParameterSetName = 'ODBC_CONNECTION')]
      [string]$UID_Secondary,

      [Parameter(
         Mandatory=$true,
         ParameterSetName = 'ODBC_CONNECTION')]
      [Security.SecureString]$PWD_Primary,

      [Parameter(
         Mandatory=$true,
         ParameterSetName = 'TOOL_TYPE')]
      [Security.SecureString]$PWD_Secondary,
#>
      [Parameter(
         Mandatory = $true,
         ParameterSetName = 'TOOL_TYPE',
         HelpMessage = "Type in `"chk`" for checking database, `"fix`" for fixing
         database issue")
      ]
      [string]$TOOLTYPE #chk , fix
   );
#>


<#
Set $debug = 1 to enable debugging printout.
#>
$debug = 1;


function Init-Variables
{
   begin
   {
      <#
        The reason of using SecureString for password:
        http://msdn.microsoft.com/en-us/library/system.security.securestring.aspx
      #>
      [string]$script:DSN_Primary = "shc_pp_32_localbuild";
      [string]$script:UID_Primary = "ad";
      [Security.SecureString]$script:PWD_Primary = '' |
        ConvertTo-SecureString -AsPlainText -Force;

      [string]$script:DSN_Secondary = "shc_ss_32_localbuild";
      [string]$script:UID_Secondary = "ad";
      [Security.SecureString]$script:PWD_Secondary = '' |
        ConvertTo-SecureString -AsPlainText -Force;

      <#
         Setup error message color showed under powershell prompt.
      #>
      $script:ErrorColor = @{ForegroundColor="White";BackgroundColor="DarkRed"};
      $script:UpdateDBErrorColor = @{ForegroundColor="Green";BackgroundColor="DarkRed"};
      $script:DebugColor = @{ForegroundColor="Yellow";BackgroundColor="DarkGray"};
   }
}


<#
Just for testing any variables...
#>
if ($debug)
{
}

Init-Variables;

<#
Contains different kind of print layout
#>
function Set-PrintLayout
{
}


function Prepare-DBConnectionString( [switch] $PairDB )
{
   $marshal = [Runtime.InteropServices.Marshal];

   if ($PairDB)
   {
      $OdbcPrimaryConnString = New-Object System.Data.Odbc.OdbcConnectionStringBuilder;
      $OdbcPrimaryConnString.Dsn = $DSN_Primary;
      $OdbcPrimaryConnString.Add("UID", $UID_Primary);
      $OdbcPrimaryConnString.Add(
         "PWD", $marshal::PtrToStringAuto( $marshal::SecureStringToBSTR($PWD_Primary)));

      $OdbcSecondaryConnString = New-Object System.Data.Odbc.OdbcConnectionStringBuilder;
      $OdbcSecondaryConnString.Dsn = $DSN_Secondary;
      $OdbcSecondaryConnString.Add("UID", $UID_Secondary);
      $OdbcSecondaryConnString.Add(
         "PWD", $marshal::PtrToStringAuto( $marshal::SecureStringToBSTR($PWD_Secondary)));

      <#
         Print out ODBC connection string
      #>
      if ($debug)
      {
         write-host @DebugColor "`$OdbcPrimaryConnString.ConnectionString : $($OdbcPrimaryConnString.ConnectionString)";
         write-host @DebugColor "`$OdbcSecondaryConnString.ConnectionString : $($OdbcSecondaryConnString.ConnectionString)";
      }

      return @($OdbcPrimaryConnString.ConnectionString,
               $OdbcSecondaryConnString.ConnectionString);
   }
   else
   {
      $OdbcPrimaryConnString = New-Object System.Data.Odbc.OdbcConnectionStringBuilder;
      $OdbcPrimaryConnString.Dsn = $DSN_Primary;
      $OdbcPrimaryConnString.Add("UID", $UID_Primary);
      $OdbcPrimaryConnString.Add(
         "PWD", 'ca$hc0w');
         #$marshal::PtrToStringAuto( $marshal::SecureStringToBSTR($PWD_Primary)));

      return ,$OdbcPrimaryConnString.ConnectionString;
   }
}


<#
-switch $PairDB : if need both Primary and Secondary DB connection , set this switch
#>
function Create-DBConnection( [switch] $PairDB )
{
   begin
   {
      $ConnStrs = Prepare-DBConnectionString -PairDB: $PairDB;

      <#
         Print out ODBC connection string
      #>
      if ($debug)
      {
         write-host @DebugColor "Create-DBConnection : begin : `$ConnStrs[0] : $($ConnStrs[0])";
         write-host @DebugColor "Create-DBConnection : begin : `$ConnStrs[1] : $($ConnStrs[1])";
      }

      if ($PairDB)
      {
         $PrimaryConnection = New-Object System.Data.Odbc.OdbcConnection($ConnStrs[0])
         $PrimaryConnection.Open()
         $SecondaryConnection = New-Object System.Data.Odbc.OdbcConnection($ConnStrs[1])
         $SecondaryConnection.Open()
      }
      else
      {
         $PrimaryConnection = New-Object System.Data.Odbc.OdbcConnection($ConnStrs[0])
         $PrimaryConnection.Open()
      }
   }

   process
   {
   }

   end
   {
      if ($PairDB)
      {
         return @($PrimaryConnection, $SecondaryConnection);
      }
      else
      {
         return ,$PrimaryConnection;
      }
   }
}


<#
pr link : http://bugzilla.eng.vmware.com/show_bug.cgi?id=1005636
opengrok : https://opengrok.eng.vmware.com/source/xref/glenlivet.perforce-aog.1750/src/recovery/engine/planData.cpp#1230
#>
function Check-Bug1005636($DBConns)
{
   <#
      Print out ODBC Connection state
   #>
   if ($debug)
   {
      write-host @DebugColor "Check-Bug1005636 : `$DBConn[0].State : $($DBConns[0].State)";
      write-host @DebugColor "Check-Bug1005636 : `$DBConn[1].State : $($DBConns[1].State)";
   }

   $TableFullNames = & {
         param($Connections)
         $SchemaInfoPrim = ($Connections[0].GetSchema("Tables") |
            Where-Object {$_.TABLE_NAME -eq "pdr_planproperties"});

         $SchemaInfoSec = ($Connections[1].GetSchema("Tables") |
            Where-Object {$_.TABLE_NAME -eq "pdr_planproperties"});

         if ($debug)
         {
            write-host @DebugColor "Check-Bug1005636 : `$SchemaInfoPrim : $($SchemaInfoPrim)";
            write-host @DebugColor "Check-Bug1005636 : `$SchemaInfoSec : $($SchemaInfoSec)";
         }

         return ("[$($SchemaInfoPrim.TABLE_CAT)].[$($SchemaInfoPrim.TABLE_SCHEM)].[$($SchemaInfoPrim.TABLE_NAME)]",
          "[$($SchemaInfoSec.TABLE_CAT)].[$($SchemaInfoSec.TABLE_SCHEM)].[$($SchemaInfoSec.TABLE_NAME)]");
   } $DBConns;

   <#
      Print out Full Table Names
   #>
   if ($debug)
   {
      write-host @DebugColor "Check-Bug1005636 : `$TableFullNames[0] : $($TableFullNames[0])";
      write-host @DebugColor "Check-Bug1005636 : `$TableFullNames[1] : $($TableFullNames[1])";
   }


   function Get-PlanPropertiesData
   {
      param($TableFullNames, $Connections)
      $OdbcCommandPrim = New-Object System.Data.Odbc.OdbcCommand `
         ("SELECT [db_id], [mo_id], [peerplanmoid], [syncversion], [peersyncversion], [syncstate] FROM $($TableFullNames[0])" , $Connections[0]);

      $OdbcCommandSec = New-Object System.Data.Odbc.OdbcCommand `
         ("SELECT [db_id], [mo_id], [peerplanmoid], [syncversion], [peersyncversion], [syncstate] FROM $($TableFullNames[1])" , $Connections[1]);
      return @($OdbcCommandPrim.ExecuteReader([System.Data.CommandBehavior]::KeyInfo), $OdbcCommandSec.ExecuteReader([System.Data.CommandBehavior]::KeyInfo));
   }
   $SitesData = Get-PlanPropertiesData $TableFullNames $DBConns;


   function Test-Sync-Gt-Peer
   {
      param($SitesData)
      function Testing
      {
         process
         {
            foreach ($row in $_[0])
            {
               $syncVersion = $row.GetValue($row.GetOrdinal("syncversion"));
               $peerSyncVersion = $row.GetValue($row.GetOrdinal("peersyncversion"));

               if ( $syncVersion -ge $peerSyncVersion ) #change to -ge for debug
               {
                  write-host @ErrorColor ("Error found! Table {0} Record [db_id] : {1} has syncversion : {2} less then peersyncverion : {3}." -f `
                     $_[1], $row.GetValue($row.GetOrdinal("db_id")), $syncVersion, $peerSyncVersion);
               }
            }
         }
      }
      ($SitesData[0], $TableFullNames[0]), ($SitesData[1], $TableFullNames[1]) | Testing;
   }
   Test-Sync-Gt-Peer $SitesData;


   function Test-Sync-Gt-RemotePeer
   {
      param ($SitesData)
      function Testing
      {
         param($Site1, $Site2)
         foreach ($row in $Site1[0])
         {
            $PeerMoid = $row.GetValue($row.GetOrdinal("peerplanmoid"));
            $PeerPlan_Record = $Site2[0] | Where-Object {$_.GetValue($_.GetOrdinal("mo_id")) -eq $PeerMoid};

            if ($PeerPlan_Record -eq $null)
            {
               write-host @ErrorColor ("Error found! Table {0} Record [db_id] : {1} has peerplanmoid : {2} that does not have same mo_id entry on Table {3}" -f `
                     $Site1[1], $row.GetValue($row.GetOrdinal("db_id")), $PeerMoid, $Site2[1]);
               continue;
            }

            $remote_peerSyncVersion =  $PeerPlan_Record.GetValue($PeerPlan_Record.GetOrdinal("peersyncversion"));
            $syncVersion = $row.GetValue($row.GetOrdinal("syncversion"));

            if ( $syncVersion -eq $remote_peerSyncVersion )
            {
               write-host @ErrorColor ("Error found! Table {0} Record [db_id] : {1} has syncversion : {2} less then remote peersyncverion : {3}." -f `
                  $Site1[1], $row.GetValue($row.GetOrdinal("db_id")), $syncVersion, $remote_peerSyncVersion);
            }
         }
      }
      Testing ($SitesData[0], $TableFullNames[0]) ($SitesData[1], $TableFullNames[1]);
      $SitesData = Get-PlanPropertiesData $TableFullNames $DBConns;
      Testing ($SitesData[1], $TableFullNames[1]) ($SitesData[0], $TableFullNames[0]);
   }
   $SitesData = Get-PlanPropertiesData $TableFullNames $DBConns;
   Test-Sync-Gt-RemotePeer $SitesData;


   function Get-CatalogName
   {
      [CmdletBinding()]
      param([Parameter(Mandatory=$true)][System.Data.Odbc.OdbcConnection]$Connection)

      <#
         Print out ODBC Connection state
      #>
      if ($debug)
      {
         write-host @DebugColor "Check-Bug1005636 : Get-CatalogName : `$Connection.State : $($Connection.State)";
      }

      return $Connection.GetSchema("Tables") | Select-Object -ExpandProperty TABLE_CAT -First 1
   }
   #$Table_Cat = Get-CatalogName $DBConns[0];
   #write-host $Table_Cat;
}


function Fix-Bug1005636($DBConns)
{
   <#
      Print out ODBC Connection state
   #>
   if ($debug)
   {
      write-host @DebugColor "Fix-Bug1005636 : `$DBConn[0].State : $($DBConns[0].State)";
      write-host @DebugColor "Fix-Bug1005636 : `$DBConn[1].State : $($DBConns[1].State)";
   }


   $TableFullNames = & {
         param($Connections)
         $SchemaInfoPrim = ($Connections[0].GetSchema("Tables") |
            Where-Object {$_.TABLE_NAME -eq "pdr_planproperties"});

         $SchemaInfoSec = ($Connections[1].GetSchema("Tables") |
            Where-Object {$_.TABLE_NAME -eq "pdr_planproperties"});

         if ($debug)
         {
            write-host @DebugColor "Fix-Bug1005636 : `$SchemaInfoPrim : $($SchemaInfoPrim)";
            write-host @DebugColor "Fix-Bug1005636 : `$SchemaInfoSec : $($SchemaInfoSec)";
         }

         return ("[$($SchemaInfoPrim.TABLE_CAT)].[$($SchemaInfoPrim.TABLE_SCHEM)].[$($SchemaInfoPrim.TABLE_NAME)]",
          "[$($SchemaInfoSec.TABLE_CAT)].[$($SchemaInfoSec.TABLE_SCHEM)].[$($SchemaInfoSec.TABLE_NAME)]");
   } $DBConns;


   <#
      Print out Full Table Names
   #>
   if ($debug)
   {
      write-host @DebugColor "Fix-Bug1005636 : `$TableFullNames[0] : $($TableFullNames[0])";
      write-host @DebugColor "Fix-Bug1005636 : `$TableFullNames[1] : $($TableFullNames[1])";
   }


   function Get-PlanPropertiesData
   {
      param($TableFullNames, $Connections)
      $OdbcCommandPrim = New-Object System.Data.Odbc.OdbcCommand `
         ("SELECT [db_id], [mo_id], [peerplanmoid], [syncversion], [peersyncversion], [syncstate] FROM $($TableFullNames[0])" , $Connections[0]);

      $OdbcCommandSec = New-Object System.Data.Odbc.OdbcCommand `
         ("SELECT [db_id], [mo_id], [peerplanmoid], [syncversion], [peersyncversion], [syncstate] FROM $($TableFullNames[1])" , $Connections[1]);
      return @($OdbcCommandPrim.ExecuteReader([System.Data.CommandBehavior]::KeyInfo), $OdbcCommandSec.ExecuteReader([System.Data.CommandBehavior]::KeyInfo));
   }
   $SitesData = Get-PlanPropertiesData $TableFullNames $DBConns;


   function Check-Violates-And-Solve-It
   {
      param($SitesData)

      function Testing-Rule1
      {
         process
         {
            foreach ($row in $_[0])
            {
               $dbId = $row.GetValue($row.GetOrdinal("db_id"));
               $syncVersion = $row.GetValue($row.GetOrdinal("syncversion"));
               $peerSyncVersion = $row.GetValue($row.GetOrdinal("peersyncversion"));
               $PeerMoid = $row.GetValue($row.GetOrdinal("peerplanmoid"));
               $PeerPlan_Record = $_[3] | Where-Object {$_.GetValue($_.GetOrdinal("mo_id")) -eq $PeerMoid};

               if ($PeerPlan_Record -eq $null)
               {
                  write-host @ErrorColor ("Error found! Table {0} Record [db_id] : {1} has peerplanmoid : {2} that does not have same mo_id entry on Table {3}" -f `
                        $Site1[1], $row.GetValue($row.GetOrdinal("db_id")), $PeerMoid, $Site2[1]);
                  continue;
               }

               $peerDbId =  $PeerPlan_Record.GetValue($PeerPlan_Record.GetOrdinal("db_id"));

               if ( $syncVersion -ge $peerSyncVersion ) #change to -ge for debug
               {
                  write-host @ErrorColor ("Error found! Table {0} Record [db_id] : {1} has syncversion : {2} less then peersyncverion : {3}." -f `
                     $_[1], $dbId, $syncVersion, $peerSyncVersion);

                  write-host "Fixing...";

                  if ($debug)
                  {
                     write-host @DebugColor "Fix-Bug1005636 Rule1 : Update database sql string : UPDATE $($_[1]) SET $($_[1]).[syncversion] = '9', $($_[1]).[peersyncversion] = '9', $($_[1]).[syncstate] = '0' where $($_[1]).[db_id] = `'$dbId`' ";
                  }

                  $EffectedRows = & {
                        $OdbcUpdateCommandP = New-Object System.Data.Odbc.OdbcCommand `
                           (" UPDATE $($_[1]) SET $($_[1]).[syncversion] = '9', $($_[1]).[peersyncversion] = '9', $($_[1]).[syncstate] = '0' where $($_[1]).[db_id] = `'$dbId`' " , $_[2]);
                        $OdbcUpdateCommandS = New-Object System.Data.Odbc.OdbcCommand `
                           (" UPDATE $($_[4]) SET $($_[4]).[syncversion] = '9', $($_[4]).[peersyncversion] = '9', $($_[4]).[syncstate] = '0' where $($_[4]).[db_id] = `'$peerDbId`' " , $_[5]);
                        return $OdbcUpdateCommandP.ExecuteNonQuery(), $OdbcUpdateCommandS.ExecuteNonQuery();
                  };

                  if ( $EffectedRows[0] -ne 1 )
                  {
                     write-host @UpdateDBErrorColor `
                        ("Update Database Failure! Table {0} Record [db_id] : {1} Columns syncversion and peersyncverion update value failure!" -f `
                         $_[1], $dbId);
                  }
                  elseif ( $EffectedRows[1] -ne 1 )
                  {
                     write-host @UpdateDBErrorColor `
                        ("Update Database Failure! Table {0} Record [db_id] : {1} Columns syncversion and peersyncverion update value failure!" -f `
                         $_[4], $peerDbId);
                  }
                  else
                  {
                     write-host "Fixing Done!";
                  }
               }
            }
         }
      }
      ,($SitesData[0], $TableFullNames[0], $DBConns[0], $SitesData[1], $TableFullNames[1], $DBConns[1]) |
         Testing-Rule1;

      $SitesData = Get-PlanPropertiesData $TableFullNames $DBConns;
      ,($SitesData[1], $TableFullNames[1], $DBConns[1], $SitesData[0], $TableFullNames[0], $DBConns[0]) |
         Testing-Rule1;


      function Testing-Rule2
      {
         process
         {
            foreach ($row in $_[0])
            {
               $dbId = $row.GetValue($row.GetOrdinal("db_id"));
               $PeerMoid = $row.GetValue($row.GetOrdinal("peerplanmoid"))
               $PeerPlan_Record = $_[3] | Where-Object {$_.GetValue($_.GetOrdinal("mo_id")) -eq $PeerMoid}

               if ($PeerPlan_Record -eq $null)
               {
                  write-host @ErrorColor ("Error found! Table {0} Record [db_id] : {1} has peerplanmoid : {2} that does not have same mo_id entry on Table {3}" -f `
                        $Site1[1], $row.GetValue($row.GetOrdinal("db_id")), $PeerMoid, $Site2[1]);
                  continue;
               }

               $peerDbId =  $PeerPlan_Record.GetValue($PeerPlan_Record.GetOrdinal("db_id"));
               $remote_peerSyncVersion =  $PeerPlan_Record.GetValue($PeerPlan_Record.GetOrdinal("peersyncversion"));
               $syncVersion = $row.GetValue($row.GetOrdinal("syncversion"));

               if ( $syncVersion -eq $remote_peerSyncVersion ) #remember to change to -lt
               {
                  write-host @ErrorColor ("Error found! Table {0} Record [db_id] : {1} has syncversion : {2} less then remote peersyncverion : {3}." -f `
                     $_[1], $row.GetValue($row.GetOrdinal("db_id")), $syncVersion, $remote_peerSyncVersion);

                  write-host "Fixing...";

                  if ($debug)
                  {
                     write-host @DebugColor "Fix-Bug1005636 Rule2 : Update database sql string : UPDATE $($_[1]) SET $($_[1]).[syncversion] = '7', $($_[1]).[peersyncversion] = '9', $($_[1]).[syncstate] = '0' where $($_[1]).[db_id] = `'$dbId`' ";
                  }

                  $EffectedRows = & {
                        $OdbcUpdateCommandP = New-Object System.Data.Odbc.OdbcCommand `
                           (" UPDATE $($_[1]) SET $($_[1]).[syncversion] = '7', $($_[1]).[peersyncversion] = '7', $($_[1]).[syncstate] = '0' where $($_[1]).[db_id] = `'$dbId`' " , $_[2]);
                        $OdbcUpdateCommandS = New-Object System.Data.Odbc.OdbcCommand `
                           (" UPDATE $($_[4]) SET $($_[4]).[syncversion] = '7', $($_[4]).[peersyncversion] = '7', $($_[4]).[syncstate] = '0' where $($_[4]).[db_id] = `'$peerDbId`' " , $_[5]);
                        return $OdbcUpdateCommandP.ExecuteNonQuery(), $OdbcUpdateCommandS.ExecuteNonQuery();
                  };

                  if ( $EffectedRows[0] -ne 1 )
                  {
                     write-host @UpdateDBErrorColor `
                        ("Update Database Failure! Table {0} Record [db_id] : {1} Columns syncversion and peersyncverion update value failure!" -f `
                         $_[1], $dbId);
                  }
                  elseif ( $EffectedRows[1] -ne 1 )
                  {
                     write-host @UpdateDBErrorColor `
                        ("Update Database Failure! Table {0} Record [db_id] : {1} Columns syncversion and peersyncverion update value failure!" -f `
                         $_[4], $peerDbId);
                  }
                  else
                  {
                     write-host "Fixing Done!";
                  }
               }
            }
         }
      }
      $SitesData = Get-PlanPropertiesData $TableFullNames $DBConns;
      ,($SitesData[0], $TableFullNames[0], $DBConns[0], $SitesData[1], $TableFullNames[1], $DBConns[1]) |
         Testing-Rule2;

      $SitesData = Get-PlanPropertiesData $TableFullNames $DBConns;
      ,($SitesData[1], $TableFullNames[1], $DBConns[1], $SitesData[0], $TableFullNames[0], $DBConns[0]) |
         Testing-Rule2;
   }
   Check-Violates-And-Solve-It $SitesData;
}


function testFunc ($DBConn)
{
   write-host "inTESTFUNC";
}


$CheckBugs = ,${function:Check-Bug1005636};
$FixBugs = ,${function:Fix-Bug1005636};

function Check-Database
{
   begin
   {
      #prepare output format layout
      #prepare shared odbc connection
      $DBConnection = Create-DBConnection -PairDB
   }

   process
   {
      if ($_)
      {
         & $_ $DBConnection;
      }
   }

   end
   {
      foreach ($DBConn in $DBConnection)
      {
         $DBConn.Close();

         <#
            Print out ODBC Connection state
         #>
         if ($debug)
         {
            write-host @DebugColor "ODBC Connection close state : $($DBConn.State)";
         }
      }
   }
}


function Fix-Database
{
   begin
   {
      #prepare output format layout
      #prepare shared odbc connection
      $DBConnection = Create-DBConnection -PairDB
   }

   process
   {
      if ($_)
      {
         & $_ $DBConnection;
      }
   }

   end
   {
      foreach ($DBConn in $DBConnection)
      {
         $DBConn.Close();

         <#
            Print out ODBC Connection state
         #>
         if ($debug)
         {
            write-host @DebugColor "ODBC Connection close state : $($DBConn.State)";
         }
      }
   }
}


function Main
{
   <#
      Print out misc.
   #>
   if ($debug)
   {
      write-host @DebugColor $DSN_Primary;
      write-host @DebugColor "Main";
   }

   if (Test-Path variable:script:TOOLTYPE)
   {
      switch ($TOOLTYPE)
      {
         "chk"
         {
            write-host "CHK!";
            $CheckBugs | Check-Database;
         }
         "fix"
         {
            write-host "FIX!";
            $FixBugs | Fix-Database;
         }
      }
   }
}

Main;
