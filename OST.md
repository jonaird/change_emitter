# Observable State Trees: a State Management Pattern for Flutter 


## Motivation
There is a great deal of confusion and disagreement concerning state management in the Flutter community. The Flutter team themselves have little to say on the matter other than recommending the Provider package which is a way to provide state in your application but doesn't suggest an architecture. When the Flutter team showed the BLoC pattern as one example of how to architect an app, it was misunderstood by the community as a standard that everyone should implement regardless of the use case. However, BLoC's are relatively difficult to understand and use and the original use case was to have portability of business logic between completely separate code bases (a requirement that almost no Flutter projects have).

The goal of the Observable State Tree (OST) pattern is to provide an architecture that is extremely easy to understand and use, powerful and flexible enough to scale with your application and designed specifically around Flutter's constraints and affordances. It does not attempt to be the be all end all of state management but rather a straightforward, general purpose architecture that can be used in many cases.


## Definition
![OST.webp]()
Observable State Trees (OSTs) are a state management pattern for Flutter applications. OSTs consist of a single tree of observable objects that hold all application state, data, and business logic required for the app to function. Each node of the OST corresponds to a widget in the widget tree. The objects in the OST are designed to notify listeners (i.e., the widgets) when any part of the state changes, triggering a rebuild of the widget. A widget may only depend on its corresponding node in the OST and it is the OST node's responsibility to access any data or state that exists higher up in the tree. OST's follow the "one way data flow" pattern. Responding to user interaction is also defered to the OST node ensuring that the sole responsibility of the widget itself is simply to display the UI.

## Advantages
There are several implications of OST's that result in a codebase that is simpler, easier to understand and that requires less code:
 - The OST pattern enables a clean separation of concerns between managing user data, application state, and business logic (OST) and user interface (Widget tree). 
 - Because its tree structure maps directly onto the widget tree, the amount of code required to interface between the two structures is extremely minimal and easy to understand.
 - This leads to a simpler overall architecture because one can understand the app as a single tree structure.
 - Because of unidirectional data flow, interdependencies are clearly identified and easier to manage. 
 - Wrapping all state in observable objects further reduces the need for boilerplate code. Simply updating the state will cause all listeners to update as well.
 - Testing becomes very straightforward using OST's. Business logic and app state can be tested completely independently from widgets and OST's can be easily mocked for widget golden tests. 

## Limitations

OST's naturally result in code that is organized in a tree structure and thus may not be appropriate in cases where this is not optimal. For example in real time video games or the engine of photo editing software where a fine-grained imperative approach is  more suitable. It also may not be appropriate if a different way of organizing code is desired such as dividing up code in terms of features. OST's take a somewhat different approach than other architectures and some teams may fair better with more familiar patterns.

## Conclusion
Flutter's functional, declarative API along with hot reload and the portability of the Flutter engine prove to be significant forward leaps in developer experience for mobile and desktop app developers. They enable more rapid development, significant code re-use accross platforms and pixel perfect control over UI's. Observable State Trees are a promising path forward to make Flutter development even more agile and enabling even more sophisticated applications through a simple, easy to understand and yet powerful architecture.
