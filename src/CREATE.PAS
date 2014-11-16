{//-------------------------------------------------------------------------}
{/*                                                                         }
{Copyright (C) 1990, 2009 - Apogee Software, Ltd.                           }
{                                                                           }
{This file is part of Supernova.  Supernova is free software; you can       }
{redistribute it and/or modify it under the terms of the GNU General Public }
{License as published by the Free Software Foundation; either version 3     }
{of the License, or (at your option) any later version.                     }
{                                                                           }
{This program is distributed in the hope that it will be useful,            }
{but WITHOUT ANY WARRANTY; without even the implied warranty of             }
{MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                       }
{                                                                           }
{See the GNU General Public License for more details.                       }
{                                                                           }
{You should have received a copy of the GNU General Public License          }
{along with this program; if not, see https://gnu.org/licenses or write to: }
{  Free Software Foundation, Inc.                                           }
{  51 Franklin Street, Fifth Floor                                          }
{  Boston, MA 02110-1301                                                    }
{  USA                                                                      }
{                                                                           }
{Original Source: 1990 Scott Miller                                         }
{Prepared for public release: 03/19/09 - Joe Siegler, Apogee Software, Ltd. }
{*/                                                                         }
{//-------------------------------------------------------------------------}
const max = 228;

type
   Str228 = string[228];

var
   r1,r2  : file of Str228;

BEGIN
assign(r1,'S1');
{assign(r2,'R2');}
rewrite(r1);
{rewrite(r2);}
close(r1);
{close(r2);}
writeln('File(s) Created!');
END.
