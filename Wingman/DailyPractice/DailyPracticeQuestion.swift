//
//  PracticeQuestion.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//


//
//  PracticeQuestion.swift
//  Wingman
//

import Foundation

struct DailyPracticeQuestion: Identifiable {
    let id = UUID()
    let number: Int
    let question: String
    let options: [String]
    let correctAnswerIndex: Int
    let correctExplanation: String
    let incorrectExplanation: String
}

// MARK: - Dummy Data
let practiceQuestions: [DailyPracticeQuestion] = [
    DailyPracticeQuestion(
        number: 1,
        question: "Why is approaching from a side-angle better?",
        options: [
            "Hover behind her for a bit before making your move",
            "Approach her, be confident and compliment her",
            "Go up behind her and slap them cheeks"
        ],
        correctAnswerIndex: 1,
        correctExplanation: "Feeling truely heard comes from someone giving their full, undivided attention.",
        incorrectExplanation: "The shift is internal: self-respect and reduced attention on flaws changes behavior before external validation."
    ),
    
    DailyPracticeQuestion(
        number: 2,
        question: "What does fitness primarily change before others notice your body?",
        options: [
            "Keep asking questions to warm her up",
            "It provides physical proof you take yourself seriously",
            "Tease her to create attraction",
            "Ask for her number to avoid wasting time"
        ],
        correctAnswerIndex: 1,
        correctExplanation: "The shift is internal: self-respect and reduced attention on flaws changes behavior before external validation.",
        incorrectExplanation: "Building genuine attraction requires demonstrating self-respect through actions, not just conversation techniques."
    ),
    
    DailyPracticeQuestion(
        number: 3,
        question: "What's the best way to handle rejection gracefully?",
        options: [
            "Get angry and argue your case",
            "Thank her for her time and move on politely",
            "Ask why she rejected you",
            "Try to convince her to change her mind"
        ],
        correctAnswerIndex: 1,
        correctExplanation: "Handling rejection with grace shows maturity and self-respect. It leaves a positive impression and maintains your dignity.",
        incorrectExplanation: "Negative reactions to rejection demonstrate insecurity and poor emotional control, which are unattractive traits."
    ),
    
    DailyPracticeQuestion(
        number: 4,
        question: "When is the best time to ask for her number?",
        options: [
            "Within the first 30 seconds of talking",
            "After establishing a genuine connection and shared interest",
            "Right before you leave, regardless of how it went",
            "Never ask, just give her yours"
        ],
        correctAnswerIndex: 1,
        correctExplanation: "Timing matters. Asking after building rapport shows you're interested in her as a person, not just collecting numbers.",
        incorrectExplanation: "Asking too early or without connection comes across as desperate or insincere."
    ),
    
    DailyPracticeQuestion(
        number: 5,
        question: "What's the most important factor in keeping a conversation going?",
        options: [
            "Having a list of prepared questions",
            "Talking about yourself to seem interesting",
            "Active listening and genuine curiosity",
            "Using pickup lines and humor constantly"
        ],
        correctAnswerIndex: 2,
        correctExplanation: "Active listening shows you value her thoughts and creates natural conversation flow. People enjoy talking to those who truly listen.",
        incorrectExplanation: "Scripted approaches and self-focus prevent authentic connection and make conversations feel forced."
    )
]
