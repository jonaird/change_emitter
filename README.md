# change_emitter
 
ChangeEmitter is a highly composable, flexible alternative to [ChangeNotifier](https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html) in the Flutter framework that can be used with Provider for state management. Instead of maintaining a list of callbacks, ChangeEmitters use a stream of change objects which can contain specific information about changes and are easier to manipulate. Comes with a handful of basic ChangeEmitters that you can combine to create your own state abstractions.

## Installation  
To use ChangeEmitter, add it to your dependencies in your pubspec.yaml file as well as the provider package: 
```
dependencies:
  provider:
  change_emitter:
``` 


## Usage 
To get started quickly check out the [example](https://github.com/jonaird/change_emitter/tree/master/example/lib). 
 
And the [API documentation](https://pub.dev/documentation/change_emitter/latest/change_emitter/change_emitter-library.html)

### Built in ChangeEmitters
  
Comes with ChangeEmitters for basic primitives and way to compose them.

ValueEmitter:  
```
//ValueEmitters hold simple values
var toggle = ValueEmitter(true);

//All ChangeEmitters expose a stream of changes
var subscription = boolToggle.changes.listen((change)=>print('toggle switched'));

//set a new value
toggle.value = false; //prints 'toggle switched'

//read the current value
print('current value: ' + toggle.value.toString()); // prints 'current value: false'

//Cancel the stream subscription
subscription.cancel();

//ChangeEmitters need to be disposed when they're no longer needed.
toggle.dispose(); 
```
  
ListEmitter:  
```
//Holds a list of elements  
var intList = ListEmitter([1,3,5]);  

intList.addAll([2,8,10]);
intList.retainWhere((element)=>element%2==0);  
  
var subscription = intList.notifications.listen((notif)=>print('changed'));

//ListEmitter will only emit changes when you call emit but will
//only do so if there has actually been a change.
//This allows you to perform multiple changes to the list before updating your UI
intList.emit();  //prints 'changed'
intList.emit();  //does nothing
subscription.cance();
intList.dispose();  
```  
  
MapEmitter:  
```
//A map implementation
var colorMap = MapEmitter<String,Color>({});  

colorMap['red']=Colors.red;  
colorMap.emit();  
  
colorMap.dispose();
```  
  
EmitterContainer:  
```
//EmitterContainer allows you to compose multiple ChangeEmitters into a single unit
//which is also a ChangeEmitter 

class TextState extends EmitterContainer {
  final text = ValueEmitter('Some text');  
  final bold = ValueEmitter(false);  
  final italic = ValueEmitter(false);  
  final color = ValueEmitter<Color>(Colors.red);  
    
  //Override this getter with list of all ChangeEmitters defined in this class.  
  //This has two functions. First, all of the elements will be disposed  
  //when this class is disposed (convenient!). Second, this class 
  //will also emit a change whenever a child changes.  
  @override  
  get children => [text, bold, italic, color];  
  
  //If you just want a subset of children to notify listeners you can optionally override this getter.   
  //@override  
  //get emittingChildren => [text, bold];  
}  
  
var myTextState = TextState();  
  
var subscription = myTextState.changes.listen((notif)=>'changed!');  
  
myTestState.italic.value = true;  //prints 'changed!'
  
//We can notify listeners without changing any children:  
myTextState.emit(); //prints 'changed!' 
  
//We can also change one of the children's values without causing the container to emit a change.
//The child will still emit a change however:  
myTextState.bold.quietSet(true); //nothing printed to the console  
  
//You can do this for ListEmitter/Map/Containers as well
//someListEmitter.emit(quiet: true);
  
//dispose of resources. 
subscription.cancel();
myTextState.dispose();
```  
  
### Providing and Consuming State  
ChangeEmitter uses the Provider package along with some extra classes to provide and consume state.  
  
```
//Povide your state to a part of the widget tree
//This will automatically dispose your state when removed from the widget tree

runApp(  
  ChangeEmitterProvider(  
    create: (_) => TextState(),  
    child: MyApp(),  
  )  
);  
  
class MyApp extends StatelessWidget{

  @override
  build(){
    //You can use Provider as you would expect to get and depend on your state
    //var textState = Provider.of<TextState>(context);

    return Column(
      children:[
        //You can update your UI based on just a part of your state using a selector  
        ChangeEmitterSelector<TextState,ValueEmitter<bool>>(  
          selector: (_, state) => state.bold  
          builder: (_, bold, __){  
            return Switch(  
              value: bold.value,  
              onChange: (newValue) => bold.value = newValue  
            )  
          }  
        ),  
        //Use a vanilla Consumer to update on any change to your state  
        Consumer<TextState>(  
          builder: (_, state, __){  
            return Text(  
              state.text.value,  
              style: TextStyle(  
                color: state.color.value,
                fontWeight:  
                  state.bold.value ? FontWeight.bold : FontWeight.normal,  
                fontStyle:  
                  state.italic.value ? FontStyle.italic : FontStyle.normal),  
              );  
          }  
        )  
      ]  
    );  
  }  
}  
```




