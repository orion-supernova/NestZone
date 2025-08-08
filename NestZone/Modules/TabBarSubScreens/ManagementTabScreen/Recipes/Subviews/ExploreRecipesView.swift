import SwiftUI

struct ExploreRecipesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: RecipeViewModel
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(detailedSampleRecipes) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe).environmentObject(viewModel)) {
                                RecipeCard(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    Task {
                                        await viewModel.addRecipe(
                                            title: recipe.title,
                                            description: recipe.description,
                                            tags: recipe.tags ?? [],
                                            prepTime: recipe.prepTime,
                                            cookTime: recipe.cookTime,
                                            servings: recipe.servings,
                                            difficulty: recipe.difficulty,
                                            ingredients: recipe.ingredients,
                                            steps: recipe.steps
                                        )
                                    }
                                } label: {
                                    Label("Add to My Recipes", systemImage: "plus")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .background(
                RadialGradient(
                    colors: [
                        Color.orange.opacity(0.06),
                        Color.yellow.opacity(0.04),
                        Color(.systemBackground)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 1200
                )
            )
            .navigationTitle("Explore Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Curated Picks ✨")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                    )
                Text("Discover global favorites and Turkish classics")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                    )
            }
            Spacer()
        }
    }
    
    // DETAILED curated recipes with real ingredients and steps
    private var detailedSampleRecipes: [Recipe] {
        let now = ISO8601DateFormatter().string(from: Date())
        func R(_ title: String, _ desc: String?, _ tags: [String], _ prep: Int?, _ cook: Int?, _ serv: Int?, _ diff: Recipe.Difficulty, _ ingredients: [String], _ steps: [String]) -> Recipe {
            Recipe(
                id: UUID().uuidString,
                title: title,
                description: desc,
                ingredients: ingredients,
                steps: steps,
                tags: tags,
                prepTime: prep,
                cookTime: cook,
                servings: serv,
                difficulty: diff,
                image: nil,
                homeId: "explore", // Mark as explore so no delete button
                createdBy: nil,
                created: now,
                updated: now
            )
        }
        return [
            R("Menemen", "Traditional Turkish scrambled eggs with tomatoes and peppers", ["breakfast", "healthy"], 10, 15, 2, .easy,
              ["4 large eggs", "2 medium tomatoes, diced", "1 green bell pepper, diced", "1 small onion, diced", "3 tbsp olive oil", "1 tsp salt", "1/2 tsp black pepper", "1/2 tsp red pepper flakes", "Fresh parsley for garnish"],
              ["Heat olive oil in a large skillet over medium heat", "Add onion and sauté until translucent (3-4 minutes)", "Add bell pepper and cook for 5 minutes until softened", "Add tomatoes, salt, pepper, and red pepper flakes", "Cook until tomatoes break down and mixture is saucy (8-10 minutes)", "Beat eggs in a bowl and pour into the skillet", "Gently scramble eggs with the vegetable mixture", "Remove from heat when eggs are just set", "Garnish with fresh parsley and serve with Turkish bread"]),
            
            R("Authentic Carbonara", "Classic Roman pasta with eggs, pecorino, and guanciale", ["pasta", "dinner"], 10, 15, 4, .medium,
              ["400g spaghetti", "150g guanciale or pancetta, diced", "4 large egg yolks", "1 whole egg", "100g Pecorino Romano, grated", "Freshly ground black pepper", "Salt for pasta water"],
              ["Bring large pot of salted water to boil for pasta", "Cook spaghetti until al dente", "Meanwhile, cook guanciale in large skillet until crispy", "Whisk egg yolks, whole egg, and pecorino in bowl", "Add generous black pepper to egg mixture", "Reserve 1 cup pasta water, then drain pasta", "Add hot pasta to skillet with guanciale", "Remove from heat and quickly toss with egg mixture", "Add pasta water gradually until creamy", "Serve immediately with extra pecorino and pepper"]),
            
            R("Margherita Pizza", "Classic Neapolitan pizza with San Marzano tomatoes", ["dinner"], 120, 12, 2, .medium,
              ["Pizza dough (store-bought or homemade)", "200g San Marzano tomatoes, crushed", "150g fresh mozzarella, torn", "Fresh basil leaves", "2 tbsp extra virgin olive oil", "1 clove garlic, minced", "Salt to taste"],
              ["Preheat oven to highest setting (250°C/480°F)", "Mix crushed tomatoes with minced garlic and salt", "Stretch pizza dough to 12-inch circle", "Spread thin layer of tomato sauce", "Add torn mozzarella pieces evenly", "Drizzle with olive oil", "Bake for 10-12 minutes until crust is golden", "Add fresh basil leaves immediately after removing from oven", "Let cool for 2 minutes before slicing"]),
            
            R("Chicken Tikka Masala", "Creamy British-Indian curry with tender chicken", ["dinner"], 45, 30, 4, .medium,
              ["500g boneless chicken, cubed", "200ml plain yogurt", "2 tbsp tikka masala paste", "1 large onion, diced", "3 cloves garlic, minced", "1 inch ginger, minced", "400ml canned tomatoes", "200ml heavy cream", "2 tbsp vegetable oil", "1 tsp garam masala", "Salt and cilantro for garnish"],
              ["Marinate chicken in yogurt and 1 tbsp tikka paste for 30 minutes", "Heat oil in large pan and cook chicken until browned", "Remove chicken and set aside", "Sauté onion until golden, add garlic and ginger", "Add remaining tikka paste and cook for 1 minute", "Add canned tomatoes and simmer for 10 minutes", "Blend sauce until smooth, return to pan", "Add cream and garam masala", "Return chicken to sauce and simmer 10 minutes", "Garnish with cilantro and serve with basmati rice"]),
            
            R("Turkish Kuru Fasulye", "Hearty white bean stew in tomato sauce", ["dinner", "healthy"], 20, 60, 6, .easy,
              ["500g dried white beans, soaked overnight", "1 large onion, diced", "3 cloves garlic, minced", "2 tbsp tomato paste", "400g canned tomatoes", "1 tsp paprika", "1/2 tsp cumin", "3 tbsp olive oil", "2 cups vegetable broth", "Salt and pepper to taste", "Fresh parsley for garnish"],
              ["Drain and rinse soaked beans", "Boil beans in fresh water for 45 minutes until tender", "Heat olive oil in large pot", "Sauté onion until translucent, add garlic", "Stir in tomato paste and cook for 2 minutes", "Add canned tomatoes, paprika, and cumin", "Add cooked beans and broth", "Simmer for 15-20 minutes until sauce thickens", "Season with salt and pepper", "Garnish with parsley and serve with rice"]),
            
            R("Japanese Ramen", "Rich tonkotsu broth with fresh noodles", ["soup", "dinner"], 60, 180, 2, .hard,
              ["2 portions fresh ramen noodles", "4 cups rich pork or chicken broth", "2 soft-boiled eggs, halved", "100g chashu pork, sliced", "2 green onions, sliced", "1 sheet nori seaweed", "1 tbsp miso paste", "1 tsp sesame oil", "Bamboo shoots", "Bean sprouts"],
              ["Prepare soft-boiled eggs (6.5 minutes), peel and marinate", "Heat broth in large pot until simmering", "Cook ramen noodles according to package instructions", "Whisk miso paste with small amount of hot broth", "Divide miso mixture between two bowls", "Add hot broth to bowls", "Add drained noodles", "Top with chashu pork, eggs, green onions", "Add nori, bamboo shoots, and bean sprouts", "Drizzle with sesame oil and serve immediately"]),
            
            R("Tacos al Pastor", "Mexican pork tacos with pineapple and cilantro", ["dinner"], 30, 20, 4, .medium,
              ["500g pork shoulder, thinly sliced", "3 dried guajillo chiles", "2 dried ancho chiles", "1/4 cup achiote paste", "1/4 cup orange juice", "2 cloves garlic", "1 tsp oregano", "1/2 tsp cumin", "Corn tortillas", "1/2 pineapple, diced", "1/2 white onion, diced", "Cilantro for garnish", "Lime wedges"],
              ["Soak dried chiles in hot water for 15 minutes", "Blend chiles with achiote, orange juice, garlic, oregano, cumin", "Marinate pork in chile mixture for at least 30 minutes", "Heat large skillet over high heat", "Cook pork in batches until charred and cooked through", "Warm tortillas on comal or dry skillet", "Fill tortillas with pork", "Top with diced pineapple, onion, and cilantro", "Serve with lime wedges and salsa verde"]),
            
            R("Pad Thai", "Sweet and tangy Thai stir-fried noodles", ["dinner"], 25, 15, 2, .medium,
              ["200g rice stick noodles", "2 tbsp tamarind paste", "2 tbsp fish sauce", "2 tbsp palm sugar", "2 eggs", "100g firm tofu, cubed", "2 cloves garlic, minced", "2 green onions, chopped", "1 cup bean sprouts", "50g roasted peanuts, crushed", "Lime wedges", "3 tbsp vegetable oil"],
              ["Soak rice noodles in warm water until soft", "Mix tamarind paste, fish sauce, and palm sugar for sauce", "Heat oil in wok over high heat", "Add garlic and stir-fry for 30 seconds", "Add tofu and cook until golden", "Push to one side, scramble eggs on other side", "Add drained noodles and sauce", "Toss everything together for 2-3 minutes", "Add bean sprouts and green onions", "Stir-fry for 1 more minute", "Garnish with crushed peanuts and lime wedges"]),
            
            R("French Onion Soup", "Classic bistro soup with caramelized onions and Gruyère", ["soup", "dinner"], 20, 75, 4, .medium,
              ["6 large yellow onions, thinly sliced", "4 tbsp butter", "2 tbsp olive oil", "1 tsp salt", "1/2 tsp sugar", "1/2 cup dry white wine", "6 cups beef stock", "2 bay leaves", "4 sprigs fresh thyme", "4 slices French bread", "200g Gruyère cheese, grated"],
              ["Heat butter and oil in large heavy pot", "Add onions, salt, and sugar", "Cook onions over medium heat for 45-60 minutes, stirring occasionally", "Onions should be deeply caramelized and golden brown", "Add wine and scrape up browned bits", "Add stock, bay leaves, and thyme", "Simmer for 20 minutes", "Preheat broiler", "Toast bread slices until golden", "Ladle soup into oven-safe bowls", "Top with bread and generous cheese", "Broil until cheese is bubbly and golden"]),
            
            R("Turkish Baklava", "Honey-soaked layered pastry with pistachios", ["dessert"], 60, 45, 12, .hard,
              ["1 package phyllo dough, thawed", "400g pistachios, finely chopped", "200g butter, melted", "1 tsp cinnamon", "For syrup: 2 cups sugar", "1.5 cups water", "1/2 cup honey", "1 tsp lemon juice", "1 cinnamon stick"],
              ["Preheat oven to 175°C (350°F)", "Mix chopped pistachios with cinnamon", "Brush baking dish with melted butter", "Layer half the phyllo sheets, brushing each with butter", "Spread pistachio mixture evenly", "Layer remaining phyllo, brushing each sheet", "Cut into diamond shapes with sharp knife", "Bake for 45 minutes until golden", "Meanwhile, boil syrup ingredients for 10 minutes", "Pour hot syrup over hot baklava", "Cool completely before serving (preferably overnight)"]),
            
            R("Sushi Rolls (California)", "Inside-out sushi roll with crab and avocado", ["dinner", "healthy"], 45, 0, 4, .hard,
              ["2 cups sushi rice, cooked and seasoned", "4 nori sheets", "200g imitation crab, shredded", "1 avocado, sliced", "1 cucumber, julienned", "Sesame seeds for rolling", "Soy sauce for serving", "Wasabi and pickled ginger"],
              ["Place bamboo mat in plastic wrap", "Put nori shiny-side down on mat", "Spread thin layer of rice on nori", "Sprinkle sesame seeds on rice", "Flip so nori is facing up", "Place crab, avocado, and cucumber in center", "Roll tightly using bamboo mat", "Wet knife and slice into 8 pieces", "Repeat for remaining rolls", "Serve with soy sauce, wasabi, and ginger"]),
            
            R("Avocado Toast Deluxe", "Creamy avocado on sourdough with toppings", ["breakfast", "healthy"], 10, 5, 2, .easy,
              ["2 slices sourdough bread", "1 large ripe avocado", "1 tbsp lemon juice", "Salt and pepper to taste", "1 small tomato, diced", "2 tbsp feta cheese, crumbled", "1 tbsp olive oil", "Red pepper flakes", "Microgreens for garnish"],
              ["Toast sourdough bread until golden brown", "Mash avocado with lemon juice, salt, and pepper", "Spread avocado mixture generously on toast", "Top with diced tomato", "Sprinkle crumbled feta cheese", "Drizzle with olive oil", "Add pinch of red pepper flakes", "Garnish with microgreens", "Serve immediately"]),
            
            R("Classic Brownies", "Fudgy chocolate brownies with perfect crackly top", ["dessert"], 15, 35, 16, .easy,
              ["200g dark chocolate, chopped", "175g butter", "200g caster sugar", "3 large eggs", "75g plain flour", "25g cocoa powder", "1/2 tsp salt", "100g chocolate chips (optional)"],
              ["Preheat oven to 180°C (350°F)", "Line 8-inch square pan with parchment", "Melt chocolate and butter in double boiler", "Whisk in sugar until combined", "Beat in eggs one at a time", "Sift flour, cocoa, and salt together", "Fold dry ingredients into chocolate mixture", "Add chocolate chips if using", "Pour into prepared pan", "Bake 30-35 minutes until toothpick has few moist crumbs", "Cool completely before cutting"]),
            
            R("Turkish Lahmacun", "Thin crispy flatbread topped with spiced meat", ["dinner"], 45, 12, 6, .medium,
              ["For dough: 500g flour, 1 tsp yeast, 1 tsp salt, warm water", "For topping: 300g ground lamb/beef", "2 tomatoes, finely diced", "1 onion, finely diced", "3 cloves garlic, minced", "2 tbsp tomato paste", "1 tsp paprika", "1/2 tsp cumin", "1/4 cup parsley, chopped", "Salt and pepper", "Lemon wedges for serving"],
              ["Make dough with flour, yeast, salt, and warm water", "Knead until smooth, let rise 1 hour", "Mix all topping ingredients in bowl", "Season generously with salt and pepper", "Preheat oven to maximum temperature", "Divide dough into 6 pieces", "Roll each very thin (paper-thin)", "Spread meat mixture thinly over surface", "Bake 8-10 minutes until edges are crispy", "Serve hot with lemon wedges and fresh herbs"]),
            
            R("Shakshuka", "North African eggs poached in spiced tomato sauce", ["breakfast", "healthy"], 15, 25, 4, .easy,
              ["2 tbsp olive oil", "1 large onion, diced", "1 red bell pepper, diced", "4 cloves garlic, minced", "1 tsp paprika", "1/2 tsp cumin", "1/4 tsp cayenne", "800g canned tomatoes", "1/2 tsp sugar", "6 eggs", "100g feta cheese", "Fresh parsley and cilantro", "Salt and pepper"],
              ["Heat oil in large cast-iron skillet", "Sauté onion until softened", "Add bell pepper and cook 5 minutes", "Add garlic, paprika, cumin, cayenne", "Cook until fragrant, about 1 minute", "Add tomatoes and sugar, season with salt/pepper", "Simmer 10-15 minutes until thickened", "Make wells in sauce for eggs", "Crack eggs into wells", "Cover and cook 8-12 minutes until eggs are set", "Crumble feta over top", "Garnish with herbs and serve with bread"])
        ]
    }
}