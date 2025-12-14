//
//  SupabaseManager.swift
//  Wingman
//
//  Created by Adnan Khan on 14/12/2025.
//


import Supabase
import Foundation

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://bnckmgnysfliiypvxxii.supabase.co")!,
            supabaseKey: "sb_publishable_B1an-2PeSHETguChW_Xdxg_50UYkPtb"
        )
    }
}
