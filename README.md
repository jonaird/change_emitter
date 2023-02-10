# change_emitter
A state management library for Flutter

## Yet Another State Management Library
Why does the world need another state management library? 

Rather than trying to solve everyone's problems, this library is specifically designed for implementing the observable state tree pattern. You can read more about the OST pattern and its advantages [here](OST.md).

## Installation  
To use ChangeEmitter, add it to your dependencies in your pubspec.yaml: 
```
dependencies:
  change_emitter: ^1.0.0-beta.1
``` 


## Usage 
To get started quickly, please check out the [example](https://github.com/jonaird/change_emitter/tree/master/example/lib). 
 
And the [API documentation](https://pub.dev/documentation/change_emitter/latest/change_emitter/change_emitter-library.html)

## ChangeEmitters
A `ChangeEmitter` is like a ChangeNotifier from the Flutter framework except that it exposes a stream of change objects which provide details about a change rather than holding onto a list of callbacks. This allows you to perform an action based on the specific change in question. For example if a `ValueEmitter` stores an `int`, you could cause a listener to react differently based on whether the new value is greater than or less than the old value.

This library comes with ChangeEmitters for basic primitives and a way to compose them.

ValueEmitter:  
```
//ValueEmitters hold simple values
var toggle = ValueEmitter(true);

//All ChangeEmitters expose a stream of changes
var subscription = toggle.changes.listen((change)=>print('toggle switched'));

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

var subscription = intList.changes.listen((change)=>print('changed'));

intList.addAll([2,8,10]); //prints 'changed'
intList.retainWhere((element)=>element%2==0); //prints 'changed'

//you can make multiple changes while only emitting a change once using transactions

intList.startTransaction();
intList.addAll([1,2,3]);
intList[0]=10;
intList.endTransaction(); //prints 'changed'


subscription.cance();
intList.dispose();  
```  
  
MapEmitter:  
```
//A map implementation
var colorMap = MapEmitter<String,Color>({});  

colorMap['red']=Colors.red;  
  
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
    
  //Override this getter with a set of all ChangeEmitters defined in this class.  
  //This has three functions. First, all of the elements will be disposed  
  //when this class is disposed. Second, this class 
  //will also emit a change whenever a child changes. Third, children will
  //have access to [this] as a parent and be able to use findAncestorOfExactType<T>()
  @override  
  get children => {text, bold, italic, color};  
  
  //If you just want a subset of children or even other ChangeEMitters to notify listeners you can optionally override this getter.   
  //@override  
  //get dependencies => {text, bold};  
}  
  
var myTextState = TextState();  
  
var subscription = myTextState.changes.listen((change)=>'changed!');  
  
myTestState.italic.value = true;  //prints 'changed!'
  
//dispose of resources. 
subscription.cancel();
myTextState.dispose();
```  
  
### Providing and Consuming State  
ChangeEmitter comes with a simple reimplementation of the Provider package.  
  
```
//Povide your state to a part of the widget tree
//This will automatically dispose your state when removed from the widget tree

runApp(  
  Provider(  
    state:TextState(),  
    child: MyApp(),  
  )  
);  
  
class MyApp extends StatelessWidget{

  @override
  build(){

    return Column(
      children:[
        //You can update your UI based on just a part of your state using a Reprovider  
        Reprovider<TextState,ValueEmitter<bool>>(  
          selector: (state) => state.bold  
          builder: (_, bold){  
            return Switch(  
              value: bold.value,  
              onChange: (newValue) => bold.value = newValue  
            )  
          }  
        ),  
        //Use context extensions to update on any change to your state  
        Builder(  
          builder: (builderContext){  
            var state = builderContext.depend<TextState>()
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




