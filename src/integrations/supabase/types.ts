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
      children: {
        Row: {
          avatar: string | null
          birthday: string | null
          code: string
          created_at: string
          daily_cap_hours: number
          daily_goal: number
          id: string
          name: string
          parent_id: string
          steps_per_30: number
          updated_at: string
        }
        Insert: {
          avatar?: string | null
          birthday?: string | null
          code: string
          created_at?: string
          daily_cap_hours?: number
          daily_goal?: number
          id?: string
          name: string
          parent_id: string
          steps_per_30?: number
          updated_at?: string
        }
        Update: {
          avatar?: string | null
          birthday?: string | null
          code?: string
          created_at?: string
          daily_cap_hours?: number
          daily_goal?: number
          id?: string
          name?: string
          parent_id?: string
          steps_per_30?: number
          updated_at?: string
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
          consumed_min: number
          day: string
          earned_min: number
          updated_at: string
          user_id: string
        }
        Insert: {
          consumed_min?: number
          day?: string
          earned_min?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          consumed_min?: number
          day?: string
          earned_min?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_url: string | null
          birthday: string | null
          created_at: string
          display_name: string
          email: string | null
          id: string
          role: Database["public"]["Enums"]["user_role_kind"]
          updated_at: string
          username: string
        }
        Insert: {
          avatar_url?: string | null
          birthday?: string | null
          created_at?: string
          display_name?: string
          email?: string | null
          id: string
          role?: Database["public"]["Enums"]["user_role_kind"]
          updated_at?: string
          username: string
        }
        Update: {
          avatar_url?: string | null
          birthday?: string | null
          created_at?: string
          display_name?: string
          email?: string | null
          id?: string
          role?: Database["public"]["Enums"]["user_role_kind"]
          updated_at?: string
          username?: string
        }
        Relationships: []
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
          pro_payment_method: string | null
          pro_plan: Database["public"]["Enums"]["sub_plan"]
          pro_since: string | null
          push_on: boolean
          share_location: Database["public"]["Enums"]["share_location_mode"]
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
          pro_payment_method?: string | null
          pro_plan?: Database["public"]["Enums"]["sub_plan"]
          pro_since?: string | null
          push_on?: boolean
          share_location?: Database["public"]["Enums"]["share_location_mode"]
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
          pro_payment_method?: string | null
          pro_plan?: Database["public"]["Enums"]["sub_plan"]
          pro_since?: string | null
          push_on?: boolean
          share_location?: Database["public"]["Enums"]["share_location_mode"]
          steps_per_30?: number
          theme_color?: Database["public"]["Enums"]["theme_color"]
          units?: Database["public"]["Enums"]["units_kind"]
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      leaderboard: {
        Args: { _period: string }
        Returns: {
          avatar_url: string
          display_name: string
          rank: number
          total_steps: number
          user_id: string
          username: string
        }[]
      }
    }
    Enums: {
      app_role: "admin" | "user"
      restriction_kind: "app" | "category" | "website"
      share_location_mode: "off" | "while_using" | "always"
      step_source: "api" | "manual" | "healthkit" | "healthconnect"
      sub_plan: "monthly" | "yearly"
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
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
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
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
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
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
      sub_plan: ["monthly", "yearly"],
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
