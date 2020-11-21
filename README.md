# Firebird_ODS_11to12_converter
Firebird On-Disk-Structure (ODS) converter

Firebird "ODS 11 to 12" is a scripting tool that converts Firebird database in ODS 11 structure to ODS 12. In practice it means that the tool converts the database file from Firebird 2.x to a form compatible with Firebird 3.x.

The tool uses files extracted from the Firebird 2.5.9 and 3.0.7 server, mainly the gbak tool, but also many other files, necessary for gbak operation. 

To perform the database conversion you do not need to install Firebird server, neither version 2.x nor version 3.0. You can run them on a "clean" computer.

The scripts were written in two versions, under Windows (batch script) and under Linux (bash script).

In the Linux version, the tool requires root privileges to work, this is due to the needs of gbak itself.


| server version |   ODS  |
|----------------|--------|
| Firebird 2.0   | ODS 11 |
| Firebird 2.1   | ODS 11 |
| Firebird 2.5   | ODS 11 |
| Firebird 2.5.x | ODS 11 |
| Firebird 3.0   | ODS 12 |
| Firebird 3.x   | ODS 12 |
