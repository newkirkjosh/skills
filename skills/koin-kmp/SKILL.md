---
name: koin-kmp
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Reference for wiring dependency injection with Koin 4 in a Kotlin Multiplatform project: where definitions and ViewModels live, registering modules at every platform entry point, ViewModels with runtime parameters, and the verify() and resolve tests that catch missing definitions before a screen crashes. For Metro projects use metro-kmp."
metadata:
  type: rigid
---

# Koin 4 in Kotlin Multiplatform

## Where things go

| Definition | Module lives in | DSL |
|---|---|---|
| API clients, repositories, use cases | the owning module's `commonMain` | `single<Iface> { Impl(get()) }`, `factory { UseCase(get()) }` |
| ViewModels | the feature module's `commonMain` | `viewModel { MyViewModel(get()) }` from `org.koin.core.module.dsl.viewModel` |
| Platform types (token store, config, anything needing `Context`) | `androidMain` / `jvmMain` / `iosMain` platform module | `single<TokenStore> { AndroidTokenStore(androidContext()) }` |

Koin 4 runs ViewModels in common code, so they belong with their feature, not in a platform module. Feature modules depend on `koin-core` and `koin-compose-viewmodel`; only the Android app module adds `koin-android`. Shared code never references a platform type; it depends on an interface the platform module binds.

## Register every module at every entry point

Each target has its own `startKoin`, and each must list **every** shared module plus its own platform module:

```kotlin
// androidMain: Application.onCreate()
startKoin { androidContext(this@App); modules(coreModule, androidPlatformModule, onboardingModule, habitsModule) }

// jvmMain: main()
startKoin { modules(coreModule, jvmPlatformModule, onboardingModule, habitsModule) }

// iosMain: called from the Swift app before the first view
fun initKoin() = startKoin { modules(coreModule, iosPlatformModule, onboardingModule, habitsModule) }
```

Adding a feature module means adding it to **all** of these. A module missing from one entry point compiles fine and crashes only when that target opens the screen (`NoDefinitionFoundException`). To keep the lists from drifting, define `val sharedModules = listOf(coreModule, onboardingModule, habitsModule)` once in `commonMain` and call `modules(sharedModules + platformModule)` everywhere.

## ViewModels with runtime parameters

```kotlin
viewModel { (habitId: String) -> HabitDetailViewModel(get(), habitId) }

// at the call site
val vm: HabitDetailViewModel = koinViewModel(parameters = { parametersOf(habitId) })
```

Parameters are positional and typed at runtime; a wrong order or type fails only when the screen opens. Keep parameter lists short, and pass IDs rather than whole objects where you can.

## Test the graph: verify() plus a resolve test

Two checks, because each misses what the other catches:

- **`Module.verify()`** (from `koin-test`, JVM-only because it uses reflection) checks that every *registered* definition's constructor dependencies have definitions. It does **not** notice a whole module left out of an entry point: nothing registered refers to the missing ViewModels, so it passes. (A desktop entry point that leaves out `habitsModule` still passes `verify()`.)
- **A resolve test** starts Koin with the entry point's exact module list and gets every screen's ViewModel. This is what catches a missing module.

```kotlin
@OptIn(KoinExperimentalAPI::class) // definition() and injectedParameters() are experimental in 4.0
class KoinGraphSpec : DescribeSpec({
    val desktopModules = sharedModules + jvmPlatformModule
    afterEach { stopKoin() }

    it("every registered definition's dependencies resolve") {
        module { includes(desktopModules) }.verify(
            extraTypes = listOf(HttpClient::class, String::class), // built in lambdas / passed as parameters
            injections = injectedParameters(definition<HabitDetailViewModel>(String::class)),
        )
    }

    it("every screen ViewModel resolves") {
        val koin = startKoin { modules(desktopModules) }.koin
        koin.get<HabitListViewModel>() shouldNotBe null
        koin.get<HabitDetailViewModel>(parameters = { parametersOf("h-1") }) shouldNotBe null
    }
})
```

Add `koin-test` (same version ref as `koin-core`) to the JVM test source set. List every parameterized definition in `injectedParameters`, and in `extraTypes` every type `verify()` can't construct: objects built inside a definition lambda (an `HttpClient` from a builder) and the parameter types themselves. Find the list by running it; the failure names each missing type. `checkModules()` is the deprecated predecessor; don't add new uses. Neither test checks that the entry points actually *use* `sharedModules`; launching each target does.

## Gotchas

- One `startKoin` per process. Tests that start Koin call `stopKoin()` in teardown, or the next test fails with `KoinApplicationAlreadyStartedException`.
- `single` for long-lived objects (clients, repositories), `factory` for per-use objects. A ViewModel is never a `single`.
- Constructor injection with `get()` only; never call `KoinComponent.get()` / `inject()` from business code.
