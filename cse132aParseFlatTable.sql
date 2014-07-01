/**
* Code used for CSE 132A at UCSD with James Mack and Jun Abbott 
*/

--Note:
-- player1 race and player2 race filled in on game table 
-- all references in tables to other tables uses [table]_id
--  (except game_winner in game which is varchar)

USE [cse132a]
GO
/****** Object:  StoredProcedure [dbo].[dba_parse_flat_table]    Script Date: 07/18/2012 21:28:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:  <Spencer Ochs, James Mack, Jun Abbott>
-- Create date: <7/18/2012>
-- Description: <Blah blah blah>
-- =============================================
CREATE PROCEDURE [dbo].[dba_parse_flat_table]
as
begin
 delete from player
 delete from map
 delete from game
 delete from stat
 delete from league
 delete from race

 -- declare variables
 declare @player1_id int,
  @player1_name varchar(50),
  @player1_race varchar(50),
  @player1_code int,
  @player1_league varchar(50),
  @player1_apm int,
  @player1_resources int,
  @player1_units int,
  @player1_structures int,
  @player2_id int,
  @player2_name varchar(50),
  @player2_race varchar(50),
  @player2_code int,
  @player2_league varchar(50),
  @player2_apm int,
  @player2_resources int,
  @player2_units int,
  @player2_structures int,
  @map_name varchar(50),
  @map_spawns int,
  @map_size varchar(50),
  @game_matchup varchar(50),
  @game_time datetime,
  @game_length varchar(50),
  @game_winner varchar(50)
 declare @map_id int,
   @game_id     int,
   @stat_id int,
   @exist  int  --not currently used
  
 -- create a cursor to loop through each row in the flat table
 -- for each row, we need to insert data to player, map, game, stat tables
 -- if they don't already exist
 
 declare curs1 cursor
 for
 select
  player1_name,
  player1_race,
  player1_code,
  player1_league,
  player1_apm,
  player1_resources,
  player1_units,
  player1_structures,
  player2_name,
  player2_race,
  player2_code,
  player2_league,
  player2_apm,
  player2_resources,
  player2_units,
  player2_structures,
  map_name,
  map_spawns,
  map_size,
  game_matchup,
  game_time,
  game_length,
  game_winner 
 from
  flat_table$
  
 open curs1
 fetch next from curs1 into @player1_name, @player1_race, @player1_code, @player1_league, @player1_apm, @player1_resources, @player1_units, @player1_structures, @player2_name, @player2_race, @player2_code, @player2_league, @player2_apm, @player2_resources, @player2_units, @player2_structures, @map_name, @map_spawns, @map_size, @game_matchup, @game_time, @game_length, @game_winner
 while (@@FETCH_STATUS = 0)
 begin
   
-- insert player1 if it doesn't already exist
  select
   @player1_id =  null
   
  select
   @player1_id =  id
  from
   player
  where
   name = @player1_name
  and code  = @player1_code
  and race  = @player1_race
  and league  = @player1_league
  if (@player1_id is null)
  begin
   print 'creating player and player id for player 1’'
   --return @player1_id for use in game and stat table
   exec cse132a_ins_player @player1_name, @player1_code, @player1_race, @player1_league, @player1_id output
  end
    
  -- insert player2 if it doesn't already exist
  select
   @player2_id =  null
   
  select
   @player2_id =  id
  from
   player
  where
   name = @player2_name
  and code  = @player2_code
  and race  = @player2_race
  and league  = @player2_league
  if (@player2_id is null)
  begin
   print 'creating player and player id for player 2’'
   --return @player2_id for use in game and stat table
   exec cse132a_ins_player @player2_name, @player2_code, @player2_race, @player2_league, @player2_id output
  end

  -- insert map it doesn't already exist
  select
   @map_id =  null
   
  select
   @map_id =  id
  from
   map
  where
   name = @map_name
  and spawns  = @map_spawns
  and size  = @map_size
  if (@map_id is null)
  begin
   print 'creating map and map_id'
   --return @map_id for use in game and stat
   exec cse132a_ins_map @map_name, @map_spawns, @map_size, @map_id output
  end

  -- insert game if it doesn't already exists, need game_id later for stat table
  select
   @game_id = null
   
  select
   @game_id = id
  from
   game
  where
   matchup  = @game_matchup
  and time  = @game_time
  and length  = @game_length
  and player1  = @player1_id
  and player1_race = @player1_race
  and player2  = @player2_id
  and player2_race = @player2_race
  and winner  = @game_winner
  and  map  = @map_id
  if (@game_id is null)
  begin
   exec cse132a_ins_game @game_matchup, @game_time, @game_length, @player1_id, @player1_race, @player2_id, @player2_race, @game_winner, @map_id, @game_id output
  end
  
  -- insert stat for player1, game_id = x, if it doesn't already exist
  select
   @stat_id = null
   
  select
   @stat_id = id
  from
   stat
  where
   player  = @player1_id
  and game  = @game_id --int
  and apm  = @player1_apm
  and resources = @player1_resources
  and units  = @player1_units
  and  structures = @player1_structures
  if (@stat_id is null)
  begin
   print 'creating stat and stat_id for player1 gameX'
   exec cse132a_ins_stat @player1_id, @game_id, @player1_apm, @player1_resources, @player1_units, @player1_structures, @stat_id output
  end

  -- insert stat for player2 game_id = x if it doesn't already exist
  select
   @stat_id = null
   
  select
   @stat_id = id
  from
   stat
  where
   player  = @player2_id
  and game  = @game_id
  and apm  = @player2_apm
  and resources = @player2_resources
  and units  = @player2_units
  and  structures = @player2_structures
  if (@stat_id is null)
  begin
   print 'creating stat and stat_id'
   exec cse132a_ins_stat @player2_id, @game_id, @player2_apm, @player2_resources, @player2_units, @player2_structures, @stat_id output
  end

  fetch next from curs1 into @player1_name, @player1_race, @player1_code, @player1_league, @player1_apm, @player1_resources, @player1_units, @player1_structures, @player2_name, @player2_race, @player2_code, @player2_league, @player2_apm, @player2_resources, @player2_units, @player2_structures, @map_name, @map_spawns, @map_size, @game_matchup, @game_time, @game_length, @game_winner

end --while loop
 
 -- close the cursor
 close curs1
 deallocate curs1
 
 select * from player
 select * from map
 select * from game
 select * from stat
 
end --parse procedure
GO


USE [cse132a]
GO
/****** Object:  StoredProcedure [dbo].[cse132a_ins_player]    Script Date: 07/19/2012 21:27:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:  <Author,,Name>
-- Create date: <Create Date,,>
-- Description: <Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[cse132a_ins_player]
 @player_name varchar(50),
 @player_code  int,
 @player_race varchar(50),
 @player_league varchar(50),
 @player_id int output
as
begin
 begin try
  begin tran
   exec cse132a_get_next_id_by_name 'player', @player_id output
   --tests
   print ‘player_id:’ + convert(varchar,@player_id)
   print ‘player_name’ + @player_name
   print ‘code’ + convert(varchar,@player_code)
   print ‘player_race’ + @player_race
   print ‘league’ + @player_league
   insert player
   (
    id,
    name,
    code,
    race,
    league
   )
   select
    @player_id,
    @player_name,
    @player_code,
    @player_race,
    @player_league
   commit
 end try
 begin catch
  IF (@@TRANCOUNT > 0)
   rollback
   RAISERROR ('Error while trying to create a player id.', -- Message text.
         16, -- Severity.
         1 -- State.
         );
  
 end catch
end
GO

USE [cse132a]
GO
/****** Object:  StoredProcedure [dbo].[cse132a_ins_game]    Script Date: 07/19/2012 21:27:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:  <Author,,Name>
-- Create date: <Create Date,,>
-- Description: <Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[cse132a_ins_game]
 @matchup varchar(50),
 @time  datetime,
 @length  varchar(50),
 @player1 int, --takes player id
 @player1_race varchar(50),
 @player2 int,
 @player2_race varchar(50),
 @winner  varchar(50), --takes player name
 @map  int, --map_id
 @game_id int output
as
begin
 begin try
  begin tran
   exec cse132a_get_next_id_by_name 'game', @game_id output
   insert game
   (
    id,
    matchup,
    time,
    length,
    player1,
    player1_race,
    player2,
    player2_race,
    winner,
    map
   )
   select
    @game_id,
    @matchup,
    @time,
    @length,
    @player1,
    @player1_race,
    @player2,
    @player2_race,
    @winner,
    @map
   commit
 end try
 begin catch
  IF (@@TRANCOUNT > 0)
   rollback
   RAISERROR ('Error while trying to create a game id.', -- Message text.
         16, -- Severity.
         1 -- State.
         );
  
 end catch
end
GO

USE [cse132a]
GO
/****** Object:  StoredProcedure [dbo].[cse132a_ins_map]    Script Date: 07/19/2012 21:27:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:  <Author,,Name>
-- Create date: <Create Date,,>
-- Description: <Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[cse132a_ins_map]
 @map_name varchar(50),
 @spawns  int,
 @size  varchar(50),
 @map_id  int output
as
begin
 begin try
  begin tran
   exec cse132a_get_next_id_by_name 'map', @map_id output
   insert map
   (
    id,
    name,
    spawns,
    size
   )
   select
    @map_id,
    @map_name,
    @spawns,
    @size
  commit
 end try
 begin catch
  IF (@@TRANCOUNT > 0)
   rollback
   RAISERROR ('Error while trying to create a map.', -- Message text.
         16, -- Severity.
         1 -- State.
         );
  
 end catch
end
GO

USE [cse132a]
GO
/****** Object:  StoredProcedure [dbo].[cse132a_ins_stat]    Script Date: 07/19/2012 21:27:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:  <Author,,Name>
-- Create date: <Create Date,,>
-- Description: <Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[cse132a_ins_stat]
 @player_id  int,
 @game_id  int,
 @player_apm  int,
 @player_resources int,
 @player_units  int,
 @player_structures int,
 @stat_id  int output
as
begin
 begin try
  begin tran
   exec cse132a_get_next_id_by_name 'stat', @stat_id output
   insert stat
   (
    id,
    player,
    game,
    apm,
    resources,
    units,
    structures
   )
   select
    @stat_id,
    @player_id,
    @game_id,
    @player_apm,
    @player_resources,
    @player_units,
    @player_structures
  commit
 end try
 begin catch
  IF (@@TRANCOUNT > 0)
   rollback
   RAISERROR ('Error while trying to create stat.', -- Message text.
         16, -- Severity.
         1 -- State.
         );
  
 end catch
end
GO

USE [cse132a]
GO
/****** Object:  StoredProcedure [dbo].[cse132a_get_next_id_by_name]    Script Date: 07/19/2012 21:27:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:  <Author,,Name>
-- Create date: <Create Date, ,>
-- Description: <Description, ,>
-- =============================================
CREATE PROCEDURE [dbo].[cse132a_get_next_id_by_name]
 @table_name varchar(50),
 @next_id int output
as
begin
 select @next_id = -1
 
 --begin try
  -- inside the "try" block, add the "begin transaction" and "commit"
  begin tran
   select
    @next_id = next_id_value
   from
    next_id
   where
    table_name = @table_name
    
   update
    next_id
   set
    next_id_value = next_id_value + 1
   where
    table_name  = @table_name
  commit
 /*end try
 begin catch
  IF (@@TRANCOUNT > 0)
      rollback
   RAISERROR ('Error while trying to obtain next_id.', -- Message text.
         16, -- Severity.
         1 -- State.
         );
 end catch
 */
end
GO

