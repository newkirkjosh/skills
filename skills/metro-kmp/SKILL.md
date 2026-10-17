---
name: metro-kmp
description: Process for wiring dependency injection with Metro (dev.zacsweers.metro compiler plugin) in a KMP project. Use when setting up Metro for the first time, declaring a dependency graph, contributing a binding, injecting a ViewModel in Compose, or when the project's CLAUDE.md names Metro as its DI framework.
metadata:
  type: rigid
---

# Metro KMP Dependency Injection

Metro is compile-time DI via a Kotlin compiler plugin — no KSP/KAPT, no runtime
module registry. The graph is validated at build time, so there is no
`checkModules`-style smoke test and no runtime resolution failures.

## When to Use
- Registering a new service, repository, or ViewModel in the DI graph
- Setting up Metro for the first time in a project
- Providing a platform-specific binding
- The project uses Metro, not Koin (check the project's CLAUDE.md; for Koin
  projects follow `koin-kmp` instead)

## Koin → Metro mapping

| Koin | Metro |
|------|-------|
| `module { }` file | none — `@ContributesBinding` / `@ContributesTo` on the types themselves |
| `single { }` | `@SingleIn(AppScope::class)` on an `@Inject` class or `@Provides` function |
| `factory { }` | unscoped `@Inject` class (new instance per injection) |
| `get()` in definitions | plain constructor parameters |
| `startKoin { modules(...) }` | `createGraph<AppGraph>()` once at app startup |
| platform Koin module | `@DependencyGraph` interface in the platform source set |
| `koinViewModel()` | `metroViewModel()` (metrox-viewmodel-compose) |
| `checkModules()` smoke test | not needed — graph validated at compile time |

## Steps

- [ ] **Step 1: Apply the Gradle plugin**

```kotlin
// module's build.gradle.kts
plugins {
    kotlin("multiplatform") // or android, jvm
    id("dev.zacsweers.metro") version "<version>"
}
```

Declare the plugin in the version catalog like every other plugin:

```toml
[versions]
metro = "<check https://zacsweers.github.io/metro/latest/compatibility/ for the version matching the project's Kotlin>"

[plugins]
metro = { id = "dev.zacsweers.metro", version.ref = "metro" }
```

The plugin adds the runtime dependency automatically — do not add
`dev.zacsweers.metro:runtime` to the version catalog by hand. Metro is a
compiler plugin: before any Kotlin version bump, confirm a Metro release
supports it on that compatibility page — Kotlin upgrades are gated on Metro,
unlike runtime-only DI libraries.

- [ ] **Step 2: Declare the graph — interface in `commonMain`, `@DependencyGraph` in the platform source set**

A graph defined in `commonMain` cannot see contributions from
platform-specific types, so the final graph always lives in platform code:

```kotlin
// commonMain — accessors only, no annotation
interface AppGraph {
    val bookRepository: BookRepository
}

// androidMain (and each other target)
@DependencyGraph(AppScope::class)   // declaring the scope implies @SingleIn(AppScope::class)
interface AndroidAppGraph : AppGraph {
    @Provides fun provideHttpEngine(): HttpClientEngine = OkHttp.create()
}
```

`AppScope` and `@SingleIn` ship in the `dev.zacsweers.metro` runtime — never
define your own. The `scope = AppScope::class` parameter is what pulls in all
`@Contributes*` types with that scope.

- [ ] **Step 3: Register types via constructor injection + contribution**

```kotlin
// commonMain — long-lived (Koin `single` equivalent)
@Inject
@SingleIn(AppScope::class)
@ContributesBinding(AppScope::class)
class BookRepositoryImpl(private val api: BookApi) : BookRepository

// commonMain — short-lived (Koin `factory` equivalent): just unscoped
@Inject
class GetBooksUseCase(private val repository: BookRepository)
```

`@ContributesBinding` binds the class to its supertype (`BookRepository`); if
the class has multiple supertypes, disambiguate with
`binding = binding<BookRepository>()`. Types you don't own (e.g. an
`HttpClient` built from the platform engine) go as `@Provides` functions on a
`@ContributesTo(AppScope::class)` interface:

```kotlin
// commonMain — chains off whatever engine the platform graph provides
@ContributesTo(AppScope::class)
interface NetworkProviders {
    @SingleIn(AppScope::class)
    @Provides fun provideHttpClient(engine: HttpClientEngine): HttpClient =
        HttpClient(engine) { install(ContentNegotiation) { json() } }
}
```

- [ ] **Step 4: Create the graph once at app startup**

```kotlin
// Android Application class
val graph = createGraph<AndroidAppGraph>()
// runtime inputs use a factory instead:
val graph = createGraphFactory<AndroidAppGraph.Factory>().create(appContext)
```

- [ ] **Step 5: ViewModels in Compose (Android/platform module)**

Add `dev.zacsweers.metro:metrox-viewmodel-compose`, then:

```kotlin
// Graph gains ViewModel multibindings + metroViewModelFactory
@DependencyGraph(AppScope::class)
interface AndroidAppGraph : AppGraph, ViewModelGraph

// Contribute each ViewModel
@Inject
@ViewModelKey
@ContributesIntoMap(AppScope::class)
class BookListViewModel(private val getBooks: GetBooksUseCase) : ViewModel()

// Root of the Compose hierarchy
CompositionLocalProvider(LocalMetroViewModelFactory provides graph.metroViewModelFactory) {
    App()
}

// Call site
@Composable
fun BookListScreen(viewModel: BookListViewModel = metroViewModel()) { ... }
```

Bare `@ViewModelKey` is correct — it's a `@MapKey(implicitClassKey = true)`,
so the annotated class keys itself; the explicit form
`@ViewModelKey(BookListViewModel::class)` is equivalent. The exception: a
ViewModel with an intermediate supertype (`class MyVm : BaseVm()`) must add
`binding<ViewModel>()` to its `@ContributesIntoMap`.

`ViewModelGraph` also requires this one-time factory boilerplate (three maps,
verbatim):

```kotlin
@Inject
@ContributesBinding(AppScope::class)
@SingleIn(AppScope::class)
class AppViewModelFactory(
    override val viewModelProviders: Map<KClass<out ViewModel>, () -> ViewModel>,
    override val assistedFactoryProviders: Map<KClass<out ViewModel>, () -> ViewModelAssistedFactory>,
    override val manualAssistedFactoryProviders: Map<KClass<out ManualViewModelAssistedFactory>, () -> ManualViewModelAssistedFactory>,
) : MetroViewModelFactory()
```

ViewModels needing runtime parameters use `@AssistedInject` + a
`@ViewModelAssistedFactoryKey(MyVm::class)`-keyed factory and
`assistedMetroViewModel()`.

**iOS**: same pattern, no metrox — declare an `@DependencyGraph(AppScope::class)`
interface in `iosMain` extending the common `AppGraph`, and expose a factory
function Swift calls once at startup:

```kotlin
// iosMain
fun createAppGraph(): AppGraph = createGraph<IosAppGraph>()
```

- [ ] **Step 6: Verify by building**

`./gradlew :module:compileKotlin<Target>` — a missing or duplicate binding is
a compile error with a resolution trace. There is nothing to smoke-test at
runtime.

## Test overrides

Replace real bindings in tests with aggregation, not a parallel module list:

```kotlin
@ContributesBinding(AppScope::class, replaces = [BookRepositoryImpl::class])
@Inject class FakeBookRepository : BookRepository

// or exclude at the graph level
@DependencyGraph(scope = AppScope::class, excludes = [RealNetworkProviders::class])
interface TestAppGraph : AppGraph
```

## Constraints
- Never inject platform-specific types (Context, Activity) into `commonMain`
  classes — provide them from the platform graph behind a common interface
- Repositories and use cases live in the shared module; ViewModels and the
  `@DependencyGraph` declaration live in platform modules
- One graph instantiation per application — hold it in the Application class
  (Android) or app entry point, never re-create per screen
- Scope on both the graph (`@SingleIn(AppScope::class)`) and the binding —
  a scoped binding on an unscoped graph is a compile error
- Don't hand-write Dagger-style `@Component`/`@Module` — Metro's aggregation
  (`@Contributes*`) replaces module files entirely

## Examples

Required (rigid skill): see Steps 2–3 above.
