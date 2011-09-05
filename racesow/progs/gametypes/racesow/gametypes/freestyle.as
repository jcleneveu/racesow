class Racesow_Gametype_Freestyle : Racesow_Gametype
{
    Racesow_Gametype_Freestyle()
    {
        for( int i= 0; i < maxClients; i++ )
            @this.players[i] = @Racesow_Player_Freestyle();
        ammoSwitch = true;
        //FIXME: These will hopefully be useable with the new angelscript version
        /*@this.commandMap["chrono"] = @Command_Chrono();
        @this.commandMap["join"] = @Command_Join();
        @this.commandMap["spec"] = @Command_Spec();
        @this.commandMap["chase"] = @Command_Chase();
        @this.commandMap["kill"] = @Command_Kill();
        @this.commandMap["position"] = @Command_Position();
        @this.commandMap["quad"] = @Command_Quad();
        @this.commandMap["noclip"] = @Command_Noclip();*/
        commandMap.set_opIndex("chrono", @Command_Chrono());
        commandMap.set_opIndex("join", @Command_Join());
        commandMap.set_opIndex("spec", @Command_Spec());
        commandMap.set_opIndex("chase", @Command_Chase());
        commandMap.set_opIndex("kill", @Command_Kill());
        commandMap.set_opIndex("position", @Command_Position());
        commandMap.set_opIndex("quad", @Command_Quad());
        commandMap.set_opIndex("noclip", @Command_Noclip());
    }
    
    void InitGametype()
    {
      gametype.setTitle( "Freestyle" );
      
      // if the gametype doesn't have a config file, create it
      if ( !G_FileExists( "configs/server/gametypes/freestyle.cfg" ) )
      {
          cString config;
    
          // the config file doesn't exist or it's empty, create it
          config = "//*\n"
                   + "//* Freestyle settings\n"
                   + "//*\n"
                   + "set g_scorelimit \"0\" // a new feature..?\n"
                   + "set g_warmup_timelimit \"0\" // ... \n"
                   + "set g_maxtimeouts \"0\" \n"
                   + "set g_disable_vote_timeout \"1\" \n"
                   + "set g_disable_vote_timein \"1\" \n"
                   + "set g_disable_vote_scorelimit \"1\" \n"
                   + "\n"
    			 + "echo freestyle.cfg executed\n";
    
          G_WriteFile( "configs/server/gametypes/freestyle.cfg", config );
          G_Print( "Created default base config file for freestyle\n" );
          G_CmdExecute( "exec configs/server/gametypes/freestyle.cfg silent" );
      }
      
      gametype.isTeamBased = false;
      gametype.hasChallengersQueue = false;
      gametype.maxPlayersPerTeam = 0;
      gametype.spawnpointRadius = 256;
      gametype.autoInactivityRemove = true;
      gametype.playerInteraction = true;
      gametype.freestyleMapFix = true;
      gametype.enableDrowning = false;

    	// disallow warmup, no matter what config files say, because it's bad for racesow timelimit.
      g_warmup_timelimit.set("0"); //g_warmup_enabled was removed in warsow 0.6
      g_allowammoswitch.set("1");
      
      G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 152 %s 90 %l 48" );
      G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Ping" );
    }
    
    void SpawnGametype()
    {
        
    }

    void Shutdown()
    {
        
    }
    
    bool MatchStateFinished( int incomingMatchState )
    {
        if (incomingMatchState == MATCH_STATE_POSTMATCH)
        {
            map.startOvertime();
            return map.allowEndGame();
        }
        return true;
    }
    
    void MatchStateStarted()
    {
        switch ( match.getState() )
        {
        case MATCH_STATE_WARMUP:
            match.launchState( MATCH_STATE_PLAYTIME );
            break;
    
        case MATCH_STATE_COUNTDOWN:
            break;
    
        case MATCH_STATE_PLAYTIME:
            map.setUpMatch();
            break;
    
        case MATCH_STATE_POSTMATCH:
            gametype.pickableItemsMask = 0;
            gametype.dropableItemsMask = 0;
            GENERIC_SetUpEndMatch();
            break;
    
        default:
            break;
        }
    }
    
    void ThinkRules()
    {
        // set all clients race stats
        cClient @client;

        for ( int i = 0; i < maxClients; i++ )
        {
            @client = @G_GetClient( i );

            if ( client.state() < CS_SPAWNED )
                continue;

            Racesow_Player @player = Racesow_GetPlayerByClient( client );
            if ( client.team != TEAM_SPECTATOR )
            {
                client.inventorySetCount( AMMO_GUNBLADE, 10 );
                if( player.onQuad )
                    client.inventorySetCount( POWERUP_QUAD, 30 );
            }
        }
    }
    
    void playerRespawn( cEntity @ent, int old_team, int new_team )
    {
        if ( ent.isGhosting() )
	        return;
	      
        Racesow_Player @player = Racesow_GetPlayerByClient( ent.client );
        cItem @item;
        cItem @ammoItem;
        if( player.wasTelekilled )
            player.resetTelekilled();

        // give all weapons
        for ( int i = WEAP_GUNBLADE; i < WEAP_TOTAL; i++ )
        {
            if ( i == WEAP_INSTAGUN ) // dont add instagun...
            continue;

            ent.client.inventoryGiveItem( i );

            @item = @G_GetItem( i );

            @ammoItem = @G_GetItem( item.weakAmmoTag );
            if ( @ammoItem != null )
            ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

            @ammoItem = @G_GetItem( item.ammoTag );
            if ( @ammoItem != null )
            ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );
        }
        
        player.restartingRace();
    }
    
    void scoreEvent( cClient @client, cString &score_event, cString &args )
    {
        Racesow_Player @player = Racesow_GetPlayerByClient( client );
        if (@player != null )
        {
            if ( score_event == "kill" )
            {
                cEntity @victim = @G_GetEntity( args.getToken( 0 ).toInt() );
                if( @victim.client == null )
                    return;
        
                Racesow_Player @victimPlayer = Racesow_GetPlayerByClient( victim.client );
                if( @victimPlayer == null )
                    return;
        
                if( @victim.client != @client ) //telekills
                {
                    if( @client.getEnt() == null)
                        return;
                    cTrace tr;
                    if( tr.doTrace( client.getEnt().getOrigin(), vec3Origin, vec3Origin, client.getEnt().getOrigin() + cVec3( 0.0f, 0.0f, 50.0f ), 0, MASK_DEADSOLID ))
                        return;
                    //spawn a gravestone to store the postition
                    cEntity @gravestone = @G_SpawnEntity( "gravestone" );
                    // copy client position
                    gravestone.setOrigin( client.getEnt().getOrigin() + cVec3( 0.0f, 0.0f, 50.0f ) );
                    victimPlayer.setupTelekilled( @gravestone );
                }
            }
        }
    }
    
    cString @ScoreboardMessage( int maxlen )
    {
        cString scoreboardMessage, entry;
        cTeam @team;
        cEntity @ent;
        int i, playerID;

        @team = @G_GetTeam( TEAM_PLAYERS );

        // &t = team tab, team tag, team score (doesn't apply), team ping (doesn't apply)
        entry = "&t " + int( TEAM_PLAYERS ) + " 0 " + team.ping + " ";
        if ( scoreboardMessage.len() + entry.len() < maxlen )
            scoreboardMessage += entry;

        // "Name Time Ping Racing"
        for ( i = 0; @team.ent( i ) != null; i++ )
        {
            @ent = @team.ent( i );
            Racesow_Player @player = Racesow_GetPlayerByClient( ent.client );

            int playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum() + 1 ) : ent.playerNum();
            entry = "&p " + playerID + " " + ent.client.getClanName() + " "
                    + ent.client.ping + " ";

            if ( scoreboardMessage.len() + entry.len() < maxlen )
                scoreboardMessage += entry;
        }
        return @scoreboardMessage;
    }
    
    cEntity @SelectSpawnPoint( cEntity @self )
    {
        Racesow_Player @player = Racesow_GetPlayerByClient( self.client );
        if( player.wasTelekilled )
        {
            return @player.gravestone;
        }
        else
        {
            return null; // select random
        }
    }
    
    bool UpdateBotStatus( cEntity @self )
    {
        return false;// let the default code handle it itself
    }
}

Racesow_Gametype@ getRacesowGametype() {
    return @Racesow_Gametype_Freestyle();
}

class Racesow_Player_Freestyle : Racesow_Player
{
    Racesow_Player_Freestyle()
    {
        this.Blocking = true;
    }

    //Override the Race gametype functions with dummy functions
    void touchStartTimer() { }

    void touchCheckPoint( int id ) { }

    void touchStopTimer() { }

    void restartRace() { }

    //This is just for consistency it'll never be called
    void touchStopTimer_gametype() { }
}
