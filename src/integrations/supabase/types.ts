export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      account_deletion_requests: {
        Row: {
          id: string
          processed_at: string | null
          reason: string | null
          requested_at: string
          user_id: string
        }
        Insert: {
          id?: string
          processed_at?: string | null
          reason?: string | null
          requested_at?: string
          user_id: string
        }
        Update: {
          id?: string
          processed_at?: string | null
          reason?: string | null
          requested_at?: string
          user_id?: string
        }
        Relationships: []
      }
      activity_steps: {
        Row: {
          calories: number
          day: string
          distance_km: number
          exercise_minutes: number
          id: string
          recorded_at: string
          source: Database["public"]["Enums"]["step_source"]
          steps: number
          updated_at: string
          user_id: string
        }
        Insert: {
          calories?: number
          day: string
          distance_km?: number
          exercise_minutes?: number
          id?: string
          recorded_at?: string
          source: Database["public"]["Enums"]["step_source"]
          steps: number
          updated_at?: string
          user_id: string
        }
        Update: {
          calories?: number
          day?: string
          distance_km?: number
          exercise_minutes?: number
          id?: string
          recorded_at?: string
          source?: Database["public"]["Enums"]["step_source"]
          steps?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      admin_account_flags: {
        Row: {
          note: string | null
          status: string
          updated_at: string
          updated_by: string | null
          user_id: string
        }
        Insert: {
          note?: string | null
          status?: string
          updated_at?: string
          updated_by?: string | null
          user_id: string
        }
        Update: {
          note?: string | null
          status?: string
          updated_at?: string
          updated_by?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "admin_account_flags_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      admin_audit_log: {
        Row: {
          aal: string | null
          action: string
          actor_id: string
          created_at: string
          details: Json
          id: string
          target_user_id: string | null
        }
        Insert: {
          aal?: string | null
          action: string
          actor_id: string
          created_at?: string
          details?: Json
          id?: string
          target_user_id?: string | null
        }
        Update: {
          aal?: string | null
          action?: string
          actor_id?: string
          created_at?: string
          details?: Json
          id?: string
          target_user_id?: string | null
        }
        Relationships: []
      }
      admin_preferences: {
        Row: {
          prefs: Json
          updated_at: string
          user_id: string
        }
        Insert: {
          prefs?: Json
          updated_at?: string
          user_id?: string
        }
        Update: {
          prefs?: Json
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      admin_pro_grants: {
        Row: {
          created_at: string
          granted_by: string | null
          note: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          granted_by?: string | null
          note?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          granted_by?: string | null
          note?: string | null
          user_id?: string
        }
        Relationships: []
      }
      admin_roles: {
        Row: {
          created_at: string
          role: string
          user_id: string
        }
        Insert: {
          created_at?: string
          role: string
          user_id: string
        }
        Update: {
          created_at?: string
          role?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "admin_roles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      admin_support_notes: {
        Row: {
          author_id: string
          category: string
          content: string
          created_at: string
          id: string
          important: boolean
          priority: string
          status: string
          updated_at: string
          user_id: string
        }
        Insert: {
          author_id?: string
          category?: string
          content: string
          created_at?: string
          id?: string
          important?: boolean
          priority?: string
          status?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          author_id?: string
          category?: string
          content?: string
          created_at?: string
          id?: string
          important?: boolean
          priority?: string
          status?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "admin_support_notes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      admin_user_deletions: {
        Row: {
          actor_id: string
          completed_at: string | null
          created_at: string
          id: string
          reason: string
          status: string
          target_user_id: string
        }
        Insert: {
          actor_id: string
          completed_at?: string | null
          created_at?: string
          id?: string
          reason: string
          status?: string
          target_user_id: string
        }
        Update: {
          actor_id?: string
          completed_at?: string | null
          created_at?: string
          id?: string
          reason?: string
          status?: string
          target_user_id?: string
        }
        Relationships: []
      }
      app_activity_days: {
        Row: {
          app_version: string | null
          day: string
          last_seen_at: string
          opens: number
          platform: string | null
          user_id: string
        }
        Insert: {
          app_version?: string | null
          day: string
          last_seen_at?: string
          opens?: number
          platform?: string | null
          user_id: string
        }
        Update: {
          app_version?: string | null
          day?: string
          last_seen_at?: string
          opens?: number
          platform?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "app_activity_days_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      app_advertisements: {
        Row: {
          content: Json
          created_at: string
          created_by: string | null
          cta_url: string | null
          ends_at: string | null
          id: string
          internal_name: string
          max_per_day: number
          max_total_per_user: number | null
          min_app_version: string | null
          min_minutes_between: number
          once_per_campaign: boolean
          priority: number
          secondary_url: string | null
          sponsor_name: string
          starts_at: string | null
          status: string
          style: Json
          targeting: Json
          template: string
          timezone: string
          updated_at: string
        }
        Insert: {
          content?: Json
          created_at?: string
          created_by?: string | null
          cta_url?: string | null
          ends_at?: string | null
          id?: string
          internal_name: string
          max_per_day?: number
          max_total_per_user?: number | null
          min_app_version?: string | null
          min_minutes_between?: number
          once_per_campaign?: boolean
          priority?: number
          secondary_url?: string | null
          sponsor_name: string
          starts_at?: string | null
          status?: string
          style?: Json
          targeting?: Json
          template?: string
          timezone?: string
          updated_at?: string
        }
        Update: {
          content?: Json
          created_at?: string
          created_by?: string | null
          cta_url?: string | null
          ends_at?: string | null
          id?: string
          internal_name?: string
          max_per_day?: number
          max_total_per_user?: number | null
          min_app_version?: string | null
          min_minutes_between?: number
          once_per_campaign?: boolean
          priority?: number
          secondary_url?: string | null
          sponsor_name?: string
          starts_at?: string | null
          status?: string
          style?: Json
          targeting?: Json
          template?: string
          timezone?: string
          updated_at?: string
        }
        Relationships: []
      }
      app_announcements: {
        Row: {
          content: Json
          created_at: string
          created_by: string | null
          dismissible: boolean
          display_mode: string
          ends_at: string | null
          id: string
          internal_name: string
          kind: string
          min_app_version: string | null
          priority: number
          requires_ack: boolean
          starts_at: string | null
          status: string
          style: Json
          targeting: Json
          timezone: string
          updated_at: string
        }
        Insert: {
          content?: Json
          created_at?: string
          created_by?: string | null
          dismissible?: boolean
          display_mode?: string
          ends_at?: string | null
          id?: string
          internal_name: string
          kind?: string
          min_app_version?: string | null
          priority?: number
          requires_ack?: boolean
          starts_at?: string | null
          status?: string
          style?: Json
          targeting?: Json
          timezone?: string
          updated_at?: string
        }
        Update: {
          content?: Json
          created_at?: string
          created_by?: string | null
          dismissible?: boolean
          display_mode?: string
          ends_at?: string | null
          id?: string
          internal_name?: string
          kind?: string
          min_app_version?: string | null
          priority?: number
          requires_ack?: boolean
          starts_at?: string | null
          status?: string
          style?: Json
          targeting?: Json
          timezone?: string
          updated_at?: string
        }
        Relationships: []
      }
      campaign_events: {
        Row: {
          campaign_id: string
          campaign_type: string
          created_at: string
          event: string
          id: string
          user_id: string
        }
        Insert: {
          campaign_id: string
          campaign_type: string
          created_at?: string
          event: string
          id?: string
          user_id: string
        }
        Update: {
          campaign_id?: string
          campaign_type?: string
          created_at?: string
          event?: string
          id?: string
          user_id?: string
        }
        Relationships: []
      }
      children: {
        Row: {
          auth_user_id: string | null
          avatar: string | null
          bedtime: string | null
          birthday: string | null
          code: string
          created_at: string
          daily_cap_hours: number
          daily_goal: number
          id: string
          invitation_expires_at: string
          invitation_status: string
          name: string
          parent_id: string
          steps_per_30: number
          updated_at: string
          username: string | null
        }
        Insert: {
          auth_user_id?: string | null
          avatar?: string | null
          bedtime?: string | null
          birthday?: string | null
          code: string
          created_at?: string
          daily_cap_hours?: number
          daily_goal?: number
          id?: string
          invitation_expires_at?: string
          invitation_status?: string
          name: string
          parent_id: string
          steps_per_30?: number
          updated_at?: string
          username?: string | null
        }
        Update: {
          auth_user_id?: string | null
          avatar?: string | null
          bedtime?: string | null
          birthday?: string | null
          code?: string
          created_at?: string
          daily_cap_hours?: number
          daily_goal?: number
          id?: string
          invitation_expires_at?: string
          invitation_status?: string
          name?: string
          parent_id?: string
          steps_per_30?: number
          updated_at?: string
          username?: string | null
        }
        Relationships: []
      }
      coach_challenges: {
        Row: {
          created_at: string
          days: number
          id: string
          metric: string
          reason: string
          start_day: string
          status: string
          target: number
          title: string
          user_id: string
        }
        Insert: {
          created_at?: string
          days: number
          id?: string
          metric: string
          reason?: string
          start_day?: string
          status?: string
          target: number
          title: string
          user_id: string
        }
        Update: {
          created_at?: string
          days?: number
          id?: string
          metric?: string
          reason?: string
          start_day?: string
          status?: string
          target?: number
          title?: string
          user_id?: string
        }
        Relationships: []
      }
      coach_insights: {
        Row: {
          created_at: string
          day: string
          input_hash: string
          payload: Json
          user_id: string
        }
        Insert: {
          created_at?: string
          day: string
          input_hash: string
          payload: Json
          user_id: string
        }
        Update: {
          created_at?: string
          day?: string
          input_hash?: string
          payload?: Json
          user_id?: string
        }
        Relationships: []
      }
      coach_messages: {
        Row: {
          content: string
          created_at: string
          id: string
          role: string
          user_id: string
        }
        Insert: {
          content: string
          created_at?: string
          id?: string
          role: string
          user_id: string
        }
        Update: {
          content?: string
          created_at?: string
          id?: string
          role?: string
          user_id?: string
        }
        Relationships: []
      }
      coach_profiles: {
        Row: {
          coaching_style: string
          main_goal: string
          personal_target: string
          preferences: Json
          strategies: Json
          updated_at: string
          user_id: string
        }
        Insert: {
          coaching_style?: string
          main_goal?: string
          personal_target?: string
          preferences?: Json
          strategies?: Json
          updated_at?: string
          user_id: string
        }
        Update: {
          coaching_style?: string
          main_goal?: string
          personal_target?: string
          preferences?: Json
          strategies?: Json
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      data_export_requests: {
        Row: {
          completed_at: string | null
          download_url: string | null
          id: string
          requested_at: string
          status: string
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          download_url?: string | null
          id?: string
          requested_at?: string
          status?: string
          user_id: string
        }
        Update: {
          completed_at?: string | null
          download_url?: string | null
          id?: string
          requested_at?: string
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      earned_balances: {
        Row: {
          bonus_min: number
          consumed_min: number
          day: string
          earned_min: number
          rollover_applied_at: string | null
          rollover_min: number
          updated_at: string
          user_id: string
        }
        Insert: {
          bonus_min?: number
          consumed_min?: number
          day?: string
          earned_min?: number
          rollover_applied_at?: string | null
          rollover_min?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          bonus_min?: number
          consumed_min?: number
          day?: string
          earned_min?: number
          rollover_applied_at?: string | null
          rollover_min?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      friend_requests: {
        Row: {
          created_at: string
          id: string
          recipient_id: string
          sender_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          recipient_id: string
          sender_id: string
        }
        Update: {
          created_at?: string
          id?: string
          recipient_id?: string
          sender_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "friend_requests_recipient_id_fkey"
            columns: ["recipient_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "friend_requests_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      friendships: {
        Row: {
          created_at: string
          friend_id: string
          id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          friend_id: string
          id?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          friend_id?: string
          id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      newsletter_subscribers: {
        Row: {
          created_at: string
          email: string
          id: string
          lang: string
        }
        Insert: {
          created_at?: string
          email: string
          id?: string
          lang?: string
        }
        Update: {
          created_at?: string
          email?: string
          id?: string
          lang?: string
        }
        Relationships: []
      }
      parent_child_relationships: {
        Row: {
          child_profile_id: string
          child_user_id: string
          id: string
          linked_at: string
          parent_id: string
        }
        Insert: {
          child_profile_id: string
          child_user_id: string
          id?: string
          linked_at?: string
          parent_id: string
        }
        Update: {
          child_profile_id?: string
          child_user_id?: string
          id?: string
          linked_at?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "parent_child_relationships_child_profile_id_fkey"
            columns: ["child_profile_id"]
            isOneToOne: true
            referencedRelation: "children"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          birthday: string | null
          country_code: string
          created_at: string
          display_name: string
          email: string | null
          id: string
          last_active_at: string | null
          onboarding_completed: boolean
          region: string
          role: Database["public"]["Enums"]["user_role_kind"]
          updated_at: string
          username: string
        }
        Insert: {
          avatar_url?: string | null
          birthday?: string | null
          country_code?: string
          created_at?: string
          display_name?: string
          email?: string | null
          id: string
          last_active_at?: string | null
          onboarding_completed?: boolean
          region?: string
          role?: Database["public"]["Enums"]["user_role_kind"]
          updated_at?: string
          username: string
        }
        Update: {
          avatar_url?: string | null
          birthday?: string | null
          country_code?: string
          created_at?: string
          display_name?: string
          email?: string | null
          id?: string
          last_active_at?: string | null
          onboarding_completed?: boolean
          region?: string
          role?: Database["public"]["Enums"]["user_role_kind"]
          updated_at?: string
          username?: string
        }
        Relationships: []
      }
      promotional_entitlements: {
        Row: {
          applied_to_settings: boolean
          created_at: string
          expires_at: string
          granted_by: string
          id: string
          plan: string
          reason: string
          revoke_reason: string | null
          revoked_at: string | null
          revoked_by: string | null
          starts_at: string
          user_id: string
        }
        Insert: {
          applied_to_settings?: boolean
          created_at?: string
          expires_at: string
          granted_by: string
          id?: string
          plan: string
          reason: string
          revoke_reason?: string | null
          revoked_at?: string | null
          revoked_by?: string | null
          starts_at?: string
          user_id: string
        }
        Update: {
          applied_to_settings?: boolean
          created_at?: string
          expires_at?: string
          granted_by?: string
          id?: string
          plan?: string
          reason?: string
          revoke_reason?: string | null
          revoked_at?: string | null
          revoked_by?: string | null
          starts_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "promotional_entitlements_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      restriction_settings: {
        Row: {
          active: boolean
          created_at: string
          id: string
          identifier: string
          kind: Database["public"]["Enums"]["restriction_kind"]
          label: string
          user_id: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          id?: string
          identifier: string
          kind: Database["public"]["Enums"]["restriction_kind"]
          label: string
          user_id: string
        }
        Update: {
          active?: boolean
          created_at?: string
          id?: string
          identifier?: string
          kind?: Database["public"]["Enums"]["restriction_kind"]
          label?: string
          user_id?: string
        }
        Relationships: []
      }
      screentime_grants: {
        Row: {
          child_user_id: string
          created_at: string
          day: string
          id: string
          minutes: number
          note: string | null
          parent_id: string
        }
        Insert: {
          child_user_id: string
          created_at?: string
          day?: string
          id?: string
          minutes: number
          note?: string | null
          parent_id: string
        }
        Update: {
          child_user_id?: string
          created_at?: string
          day?: string
          id?: string
          minutes?: number
          note?: string | null
          parent_id?: string
        }
        Relationships: []
      }
      sponsored_challenge_participants: {
        Row: {
          challenge_id: string
          completed_at: string | null
          joined_at: string
          user_id: string
        }
        Insert: {
          challenge_id: string
          completed_at?: string | null
          joined_at?: string
          user_id: string
        }
        Update: {
          challenge_id?: string
          completed_at?: string | null
          joined_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "sponsored_challenge_participants_challenge_id_fkey"
            columns: ["challenge_id"]
            isOneToOne: false
            referencedRelation: "sponsored_challenges"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sponsored_challenge_participants_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      sponsored_challenge_rewards: {
        Row: {
          badge_id: string | null
          challenge_id: string
          granted_at: string
          minutes: number
          user_id: string
        }
        Insert: {
          badge_id?: string | null
          challenge_id: string
          granted_at?: string
          minutes?: number
          user_id: string
        }
        Update: {
          badge_id?: string | null
          challenge_id?: string
          granted_at?: string
          minutes?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "sponsored_challenge_rewards_challenge_id_fkey"
            columns: ["challenge_id"]
            isOneToOne: false
            referencedRelation: "sponsored_challenges"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sponsored_challenge_rewards_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      sponsored_challenges: {
        Row: {
          content: Json
          created_at: string
          created_by: string | null
          eligibility: Json
          ends_at: string | null
          id: string
          internal_name: string
          join_closes_at: string | null
          join_mode: string
          join_opens_at: string | null
          max_claims: number | null
          metric: string
          removed_at: string | null
          reward_badge_id: string | null
          reward_minutes: number
          sponsor_logo_url: string | null
          sponsor_name: string | null
          sponsor_url: string | null
          sponsored_label: boolean
          starts_at: string | null
          status: string
          style: Json
          target: number
          timezone: string
          updated_at: string
          visible_at: string | null
        }
        Insert: {
          content?: Json
          created_at?: string
          created_by?: string | null
          eligibility?: Json
          ends_at?: string | null
          id?: string
          internal_name: string
          join_closes_at?: string | null
          join_mode?: string
          join_opens_at?: string | null
          max_claims?: number | null
          metric: string
          removed_at?: string | null
          reward_badge_id?: string | null
          reward_minutes?: number
          sponsor_logo_url?: string | null
          sponsor_name?: string | null
          sponsor_url?: string | null
          sponsored_label?: boolean
          starts_at?: string | null
          status?: string
          style?: Json
          target: number
          timezone?: string
          updated_at?: string
          visible_at?: string | null
        }
        Update: {
          content?: Json
          created_at?: string
          created_by?: string | null
          eligibility?: Json
          ends_at?: string | null
          id?: string
          internal_name?: string
          join_closes_at?: string | null
          join_mode?: string
          join_opens_at?: string | null
          max_claims?: number | null
          metric?: string
          removed_at?: string | null
          reward_badge_id?: string | null
          reward_minutes?: number
          sponsor_logo_url?: string | null
          sponsor_name?: string | null
          sponsor_url?: string | null
          sponsored_label?: boolean
          starts_at?: string | null
          status?: string
          style?: Json
          target?: number
          timezone?: string
          updated_at?: string
          visible_at?: string | null
        }
        Relationships: []
      }
      streaks: {
        Row: {
          best: number
          count: number
          last_goal_met_date: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          best?: number
          count?: number
          last_goal_met_date?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          best?: number
          count?: number
          last_goal_met_date?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      subscriptions: {
        Row: {
          cancel_at_period_end: boolean | null
          created_at: string | null
          current_period_end: string | null
          current_period_start: string | null
          environment: string
          id: string
          price_id: string
          product_id: string
          provider: string
          provider_account_id: string | null
          provider_txn_id: string
          status: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          cancel_at_period_end?: boolean | null
          created_at?: string | null
          current_period_end?: string | null
          current_period_start?: string | null
          environment?: string
          id?: string
          price_id?: string
          product_id?: string
          provider?: string
          provider_account_id?: string | null
          provider_txn_id: string
          status?: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          cancel_at_period_end?: boolean | null
          created_at?: string | null
          current_period_end?: string | null
          current_period_start?: string | null
          environment?: string
          id?: string
          price_id?: string
          product_id?: string
          provider?: string
          provider_account_id?: string | null
          provider_txn_id?: string
          status?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      task_notifications: {
        Row: {
          body: string | null
          created_at: string
          id: string
          read_at: string | null
          task_id: string | null
          title: string
          type: string
          updated_at: string
          user_id: string
        }
        Insert: {
          body?: string | null
          created_at?: string
          id?: string
          read_at?: string | null
          task_id?: string | null
          title: string
          type: string
          updated_at?: string
          user_id: string
        }
        Update: {
          body?: string | null
          created_at?: string
          id?: string
          read_at?: string | null
          task_id?: string | null
          title?: string
          type?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_notifications_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      tasks: {
        Row: {
          approved_at: string | null
          child_id: string
          child_user_id: string | null
          created_at: string
          description: string | null
          due_date: string | null
          id: string
          parent_id: string
          priority: string
          proof_image_url: string | null
          proof_note: string | null
          rejection_reason: string | null
          repeat_interval_days: number | null
          repeat_schedule: string
          reward_minutes: number
          status: string
          submitted_at: string | null
          title: string
          updated_at: string
        }
        Insert: {
          approved_at?: string | null
          child_id: string
          child_user_id?: string | null
          created_at?: string
          description?: string | null
          due_date?: string | null
          id?: string
          parent_id: string
          priority?: string
          proof_image_url?: string | null
          proof_note?: string | null
          rejection_reason?: string | null
          repeat_interval_days?: number | null
          repeat_schedule?: string
          reward_minutes?: number
          status?: string
          submitted_at?: string | null
          title: string
          updated_at?: string
        }
        Update: {
          approved_at?: string | null
          child_id?: string
          child_user_id?: string | null
          created_at?: string
          description?: string | null
          due_date?: string | null
          id?: string
          parent_id?: string
          priority?: string
          proof_image_url?: string | null
          proof_note?: string | null
          rejection_reason?: string | null
          repeat_interval_days?: number | null
          repeat_schedule?: string
          reward_minutes?: number
          status?: string
          submitted_at?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "tasks_child_id_fkey"
            columns: ["child_id"]
            isOneToOne: false
            referencedRelation: "children"
            referencedColumns: ["id"]
          },
        ]
      }
      user_badges: {
        Row: {
          badge_id: string
          created_at: string
          earned_at: string
          id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          badge_id: string
          created_at?: string
          earned_at?: string
          id?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          badge_id?: string
          created_at?: string
          earned_at?: string
          id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_daily_stats: {
        Row: {
          actual_device_screen_time_seconds: number | null
          created_at: string
          distance_km: number
          exercise_minutes: number
          id: string
          screen_time_bonus_seconds: number
          screen_time_carried_over_seconds: number | null
          screen_time_earned_seconds: number
          screen_time_remaining_seconds: number | null
          screen_time_used_seconds: number | null
          stat_date: string
          step_goal: number | null
          steps: number
          updated_at: string
          user_id: string
        }
        Insert: {
          actual_device_screen_time_seconds?: number | null
          created_at?: string
          distance_km?: number
          exercise_minutes?: number
          id?: string
          screen_time_bonus_seconds?: number
          screen_time_carried_over_seconds?: number | null
          screen_time_earned_seconds?: number
          screen_time_remaining_seconds?: number | null
          screen_time_used_seconds?: number | null
          stat_date: string
          step_goal?: number | null
          steps?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          actual_device_screen_time_seconds?: number | null
          created_at?: string
          distance_km?: number
          exercise_minutes?: number
          id?: string
          screen_time_bonus_seconds?: number
          screen_time_carried_over_seconds?: number | null
          screen_time_earned_seconds?: number
          screen_time_remaining_seconds?: number | null
          screen_time_used_seconds?: number | null
          stat_date?: string
          step_goal?: number | null
          steps?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      user_settings: {
        Row: {
          anonymous_leaderboard: boolean
          created_at: string
          daily_cap_hours: number
          daily_goal: number
          googlefit_connected: boolean
          healthkit_connected: boolean
          is_pro: boolean
          pro_auto_renew: boolean
          pro_environment: string
          pro_expires_at: string | null
          pro_payment_method: string | null
          pro_plan: Database["public"]["Enums"]["sub_plan"]
          pro_since: string | null
          pro_status: string
          push_on: boolean
          share_location: Database["public"]["Enums"]["share_location_mode"]
          st_rollover: boolean
          steps_per_30: number
          theme_color: Database["public"]["Enums"]["theme_color"]
          units: Database["public"]["Enums"]["units_kind"]
          updated_at: string
          user_id: string
        }
        Insert: {
          anonymous_leaderboard?: boolean
          created_at?: string
          daily_cap_hours?: number
          daily_goal?: number
          googlefit_connected?: boolean
          healthkit_connected?: boolean
          is_pro?: boolean
          pro_auto_renew?: boolean
          pro_environment?: string
          pro_expires_at?: string | null
          pro_payment_method?: string | null
          pro_plan?: Database["public"]["Enums"]["sub_plan"]
          pro_since?: string | null
          pro_status?: string
          push_on?: boolean
          share_location?: Database["public"]["Enums"]["share_location_mode"]
          st_rollover?: boolean
          steps_per_30?: number
          theme_color?: Database["public"]["Enums"]["theme_color"]
          units?: Database["public"]["Enums"]["units_kind"]
          updated_at?: string
          user_id: string
        }
        Update: {
          anonymous_leaderboard?: boolean
          created_at?: string
          daily_cap_hours?: number
          daily_goal?: number
          googlefit_connected?: boolean
          healthkit_connected?: boolean
          is_pro?: boolean
          pro_auto_renew?: boolean
          pro_environment?: string
          pro_expires_at?: string | null
          pro_payment_method?: string | null
          pro_plan?: Database["public"]["Enums"]["sub_plan"]
          pro_since?: string | null
          pro_status?: string
          push_on?: boolean
          share_location?: Database["public"]["Enums"]["share_location_mode"]
          st_rollover?: boolean
          steps_per_30?: number
          theme_color?: Database["public"]["Enums"]["theme_color"]
          units?: Database["public"]["Enums"]["units_kind"]
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      username_reservations: {
        Row: {
          owner_id: string
          username: string
        }
        Insert: {
          owner_id: string
          username: string
        }
        Update: {
          owner_id?: string
          username?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      accept_friend_request: {
        Args: { _request_id: string }
        Returns: undefined
      }
      account_plan: { Args: { _uid: string }; Returns: string }
      account_type: { Args: { _uid: string }; Returns: string }
      add_my_friend: { Args: { _friend_id: string }; Returns: undefined }
      admin_analytics_series: {
        Args: { _from: string; _to?: string }
        Returns: {
          dau: number
          day: string
          mau: number
          new_users: number
          pro_active_paid_or_promo: number
          pro_new: number
          sponsored_completions: number
          sponsored_joins: number
          step_active_users: number
          total_steps: number
          total_users: number
          wau: number
        }[]
      }
      admin_campaign_calendar: {
        Args: { _from: string; _to: string }
        Returns: {
          campaign_type: string
          ends_at: string
          fullscreen: boolean
          id: string
          internal_name: string
          priority: number
          starts_at: string
          status: string
          targeting: Json
        }[]
      }
      admin_campaign_stats: {
        Args: { _id: string; _type: string }
        Returns: Json
      }
      admin_can: { Args: { _perm: string }; Returns: boolean }
      admin_can_write: { Args: { _perm: string }; Returns: boolean }
      admin_dashboard_stats: { Args: never; Returns: Json }
      admin_delete_user: {
        Args: { _reason: string; _uid: string }
        Returns: string
      }
      admin_get_audit_logs: {
        Args: {
          _action?: string
          _actor?: string
          _from?: string
          _limit?: number
          _offset?: number
          _target?: string
          _to?: string
        }
        Returns: {
          aal: string
          action: string
          actor_id: string
          actor_username: string
          created_at: string
          details: Json
          id: string
          target_user_id: string
          target_username: string
          total_count: number
        }[]
      }
      admin_grant_promo: {
        Args: {
          _expires_at: string
          _plan: string
          _reason: string
          _starts_at?: string
          _uid: string
        }
        Returns: string
      }
      admin_list_admins: {
        Args: never
        Returns: {
          created_at: string
          display_name: string
          email: string
          mfa_factors: number
          roles: string[]
          user_id: string
          username: string
        }[]
      }
      admin_me: {
        Args: never
        Returns: {
          aal: string
          roles: string[]
          user_id: string
        }[]
      }
      admin_newsletter_subscribers: {
        Args: never
        Returns: {
          created_at: string
          email: string
          lang: string
        }[]
      }
      admin_overview_daily: {
        Args: { _from: string; _to?: string }
        Returns: {
          active_users: number
          avg_earned_seconds: number
          avg_steps: number
          avg_used_seconds: number
          day: string
          goal_rate: number
          new_users: number
        }[]
      }
      admin_overview_totals: {
        Args: never
        Returns: {
          active_1d: number
          active_30d: number
          active_7d: number
          total_users: number
        }[]
      }
      admin_require: {
        Args: {
          _action: string
          _details?: Json
          _perm: string
          _target?: string
        }
        Returns: undefined
      }
      admin_require_write: {
        Args: {
          _action: string
          _details?: Json
          _perm: string
          _target?: string
        }
        Returns: undefined
      }
      admin_revoke_promo: {
        Args: { _promo_id: string; _reason: string }
        Returns: undefined
      }
      admin_set_role: {
        Args: {
          _email: string
          _grant: boolean
          _reason: string
          _role: string
        }
        Returns: undefined
      }
      admin_subscription_overview: { Args: never; Returns: Json }
      admin_subscriptions_list: {
        Args: {
          _limit?: number
          _offset?: number
          _search?: string
          _status?: string
        }
        Returns: {
          cancel_at_period_end: boolean
          created_at: string
          current_period_end: string
          email: string
          environment: string
          id: string
          price_id: string
          product_id: string
          provider: string
          status: string
          total_count: number
          user_id: string
          username: string
        }[]
      }
      admin_update_user: {
        Args: {
          _account_status?: string
          _daily_cap_hours?: number
          _daily_goal?: number
          _reason?: string
          _status_note?: string
          _steps_per_30?: number
          _uid: string
        }
        Returns: undefined
      }
      admin_user_detail: { Args: { _uid: string }; Returns: Json }
      admin_user_history: {
        Args: { _from?: string; _uid: string }
        Returns: {
          actual_device_screen_time_seconds: number | null
          created_at: string
          distance_km: number
          exercise_minutes: number
          id: string
          screen_time_bonus_seconds: number
          screen_time_carried_over_seconds: number | null
          screen_time_earned_seconds: number
          screen_time_remaining_seconds: number | null
          screen_time_used_seconds: number | null
          stat_date: string
          step_goal: number | null
          steps: number
          updated_at: string
          user_id: string
        }[]
        SetofOptions: {
          from: "*"
          to: "user_daily_stats"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      admin_users: {
        Args: {
          _desc?: boolean
          _limit?: number
          _offset?: number
          _search?: string
          _sort?: string
        }
        Returns: {
          avg_daily_steps: number
          avg_earned_seconds: number
          avg_used_seconds: number
          created_at: string
          days_recorded: number
          display_name: string
          email: string
          last_active_at: string
          last_activity_date: string
          step_goal: number
          total_count: number
          total_steps: number
          user_id: string
          username: string
        }[]
      }
      admin_users_v2: {
        Args: {
          _account_type?: string
          _activity?: string
          _desc?: boolean
          _limit?: number
          _offset?: number
          _plan?: string
          _registered_from?: string
          _registered_to?: string
          _search?: string
          _sort?: string
        }
        Returns: {
          account_status: string
          account_type: string
          avatar_url: string
          created_at: string
          display_name: string
          email: string
          last_app_activity: string
          last_step_sync: string
          plan: string
          total_count: number
          user_id: string
          username: string
        }[]
      }
      app_version_gte: { Args: { _min: string; _v: string }; Returns: boolean }
      campaign_audience_match: {
        Args: {
          _is_ad: boolean
          _lang: string
          _service: boolean
          _targeting: Json
          _uid: string
        }
        Returns: boolean
      }
      claim_rollover: { Args: { _day: string }; Returns: number }
      claim_sponsored_challenge_reward:
        | { Args: { _challenge_id: string }; Returns: Json }
        | { Args: { _challenge_id: string; _day: string }; Returns: Json }
      compute_rollover: {
        Args: { _day: string; _uid: string }
        Returns: number
      }
      dismiss_friend_request: {
        Args: { _request_id: string }
        Returns: undefined
      }
      family_today: {
        Args: { _uid: string }
        Returns: {
          avatar: string
          is_self: boolean
          member_id: string
          name: string
          relation: string
          steps: number
        }[]
      }
      get_active_advertisements: {
        Args: { _app_version?: string; _lang?: string }
        Returns: {
          content: Json
          cta_url: string
          id: string
          secondary_url: string
          sponsor_name: string
          sponsored_label: string
          style: Json
          template: string
        }[]
      }
      get_active_announcements: {
        Args: { _app_version?: string; _lang?: string }
        Returns: {
          content: Json
          dismissible: boolean
          display_mode: string
          ends_at: string
          id: string
          kind: string
          priority: number
          requires_ack: boolean
          style: Json
        }[]
      }
      get_native_advertisements: {
        Args: { _app_version?: string; _lang?: string }
        Returns: {
          content: Json
          cta_url: string
          id: string
          max_per_day: number
          max_total_per_user: number
          min_minutes_between: number
          once_per_campaign: boolean
          secondary_url: string
          sponsor_name: string
          style: Json
          template: string
        }[]
      }
      get_sponsored_challenge_progress: {
        Args: { _challenge_id: string }
        Returns: Json
      }
      get_sponsored_challenges: {
        Args: { _lang?: string }
        Returns: {
          claims_remaining: number
          completed: boolean
          content: Json
          ends_at: string
          id: string
          join_closes_at: string
          join_mode: string
          join_opens_at: string
          joined: boolean
          metric: string
          phase: string
          progress: number
          reward_badge_id: string
          reward_claimed: boolean
          reward_minutes: number
          sponsor_logo_url: string
          sponsor_name: string
          sponsor_url: string
          sponsored_label: boolean
          starts_at: string
          style: Json
          target: number
        }[]
      }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      is_admin: { Args: never; Returns: boolean }
      is_parent_of: { Args: { _child_user_id: string }; Returns: boolean }
      is_privileged_caller: { Args: never; Returns: boolean }
      join_sponsored_challenge: {
        Args: { _challenge_id: string }
        Returns: undefined
      }
      leaderboard: {
        Args: { _scope: string }
        Returns: {
          avatar_url: string
          display_name: string
          rank: number
          total_steps: number
          user_id: string
          username: string
        }[]
      }
      leaderboard_ranked: {
        Args: { _day?: string; _scope: string; _uid?: string }
        Returns: {
          avatar_url: string
          display_name: string
          rank: number
          total_steps: number
          user_id: string
          username: string
        }[]
      }
      my_friend_requests: {
        Args: never
        Returns: {
          direction: string
          id: string
          name: string
          user_id: string
          username: string
        }[]
      }
      my_friends: {
        Args: never
        Returns: {
          friendship_id: string
          id: string
          name: string
          username: string
        }[]
      }
      newsletter_subscribe: {
        Args: { _email: string; _lang?: string }
        Returns: undefined
      }
      parent_family_pro: { Args: never; Returns: boolean }
      parent_family_pro_status: {
        Args: { _uid: string }
        Returns: {
          active: boolean
          cancelling: boolean
          ends_at: string
          environment: string
          status: string
        }[]
      }
      pro_is_active: { Args: { _user_id: string }; Returns: boolean }
      record_app_open: {
        Args: { _app_version?: string; _platform?: string }
        Returns: undefined
      }
      record_campaign_event: {
        Args: { _campaign_id: string; _event: string; _type: string }
        Returns: undefined
      }
      refresh_daily_stats: {
        Args: { _day: string; _uid: string }
        Returns: undefined
      }
      remove_my_friend: { Args: { _friendship_id: string }; Returns: undefined }
      report_consumed: {
        Args: { _day: string; _minutes: number }
        Returns: undefined
      }
      search_friend_users: {
        Args: { _query: string }
        Returns: {
          id: string
          name: string
          username: string
        }[]
      }
      setgoals_parent_gift: {
        Args: { p_child_id: string; p_minutes: number; p_note?: string }
        Returns: undefined
      }
      sponsored_progress_value: {
        Args: {
          _c: Database["public"]["Tables"]["sponsored_challenges"]["Row"]
          _uid: string
        }
        Returns: number
      }
      username_available: { Args: { _username: string }; Returns: boolean }
      username_is_valid: { Args: { _username: string }; Returns: boolean }
    }
    Enums: {
      app_role: "admin" | "user"
      restriction_kind: "app" | "category" | "website"
      share_location_mode: "off" | "while_using" | "always"
      step_source: "api" | "manual" | "healthkit" | "healthconnect"
      sub_plan: "monthly" | "yearly" | "family_monthly" | "family_yearly"
      theme_color:
        | "sage"
        | "rose"
        | "blue"
        | "pink"
        | "lavender"
        | "amber"
        | "slate"
      units_kind: "metric" | "imperial"
      user_role_kind: "individual" | "parent" | "child"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["admin", "user"],
      restriction_kind: ["app", "category", "website"],
      share_location_mode: ["off", "while_using", "always"],
      step_source: ["api", "manual", "healthkit", "healthconnect"],
      sub_plan: ["monthly", "yearly", "family_monthly", "family_yearly"],
      theme_color: [
        "sage",
        "rose",
        "blue",
        "pink",
        "lavender",
        "amber",
        "slate",
      ],
      units_kind: ["metric", "imperial"],
      user_role_kind: ["individual", "parent", "child"],
    },
  },
} as const
