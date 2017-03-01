---
layout: post
title: Preferred languages and iOS&nbsp;9
---

In iOS 9 Apple introduced some [changes](https://developer.apple.com/library/ios/technotes/tn2418/_index.html#//apple_ref/doc/uid/DTS40016588-CH1-LANGUAGE_IDENTIFIERS_IN_IOS_9) at how NSLocale `+preferredLanguages` returns languages. It returns strings like `en-US`, `ru-RU` instead of `en`, `ru` as it used to. Some (looks like a lot) of developers got confused by that, they reported that behavior as a bug, it even broke some codebases. The sad truth is that if this change breaks your codebase, you used it wrong making false assumptions.

As I've noted in my [previous article]({% post_url 2015-9-22-understanding-ios-internationalization %}), `+preferredLanguages` returns `language ID`s. In iOS and OS X `Language ID` [is a combination of](https://developer.apple.com/library/ios/documentation/MacOSX/Conceptual/BPInternational/LanguageandLocaleIDs/LanguageandLocaleIDs.html):

 1. **Required** language designator, like `en` or `ru`.
 2. **Optional** script designator, like `Hans` or `Hant`.
 3. **Optional** region designator like `US` or `RU` or `GB`.

joined by hyphen `-`. These are valid `language IDs`: `en`, `ru`, `en-US`, `en-RU`, `ru-RU`, `zh-Hans`, `zh-Hans-US`, `zh`.

> Even before iOS 9 `+[NSLocale preferredLanguages]` always returned list of valid `language ID`s, the only thing changed is that **since iOS 9 they are most likely include region designator**, for example `en-US`, `ru-RU` vs `en`, `ru`. 

That is, if you expected it to return **not** `language ID`s but language  **designator**-s such as `en` or `ru` (which are at the same time wide range `language ID`s without region designator specified), you, probably, did it wrong even before iOS 9.
To work around this issue or make some fast fixes you may use `+componentsFromLocaleIdentifier:` from `NSLocale`, here is an example of how it could be done:


<!-- language: lang-objc -->
``` objc
NSArray *preferredLanguages = [NSLocale preferredLanguages];

NSLog(@"[NSLocale currentLocale] = %@", [NSLocale currentLocale].localeIdentifier);
NSLog(@"[NSLocale preferredLanguages] = %@", preferredLanguages);

// extracted language designators will go here
NSMutableArray *extractedLanguageDesignators = [NSMutableArray array];

for(NSString *languageID in preferredLanguages)
{
    // extract components
    NSDictionary *components = [NSLocale componentsFromLocaleIdentifier:languageID];
    // get language designator
    NSString *languageDesignator = components[NSLocaleLanguageCode];

    if(languageDesignator != nil) // it will never be nil for a valid language-id, but i'm paranoid
    {
        [extractedLanguageDesignators addObject:languageDesignator];
    }
}

NSLog(@"extracted language designators: %@", extractedLanguageDesignators);
```

And that what it returns with preferred languages set to `Russian`, `Africaans`, `Chinese (Simplified)`, `Italian`, `English` and region set to `United States` (region language left automatic, i.e. `Russian` in this case):

```
// iOS 9
> [NSLocale currentLocale] = ru_US
> [NSLocale preferredLanguages] = (
    "ru-US",
    "af-US",
    "zh-Hans-US",
    "it-US",
    "en-US"
)
> extracted language designators: (
    ru,
    af,
    zh, <----- see, it misses script!
    it,
    en
)
```

```
// iOS 8
> [NSLocale currentLocale] = ru_US
> [NSLocale preferredLanguages] = (
    ru,
    af,
    "zh-Hans",
    it,
    en
)
> extracted language designators: (
    ru,
    af,
    zh, <--- yepp, no script again
    it,
    en
)
```
Last one is what you wanted, right? Wrong. Last one is a list of language designators, not `language ID`s. For example `zh-Hans` got truncated to `zh`, which is pretty huge loss of semantics. Of course you can crutch that too and make use of other keys:

<!-- language: lang-objc -->
``` objc
NSLog(@"zh-Hans-US components: %@", [NSLocale componentsFromLocaleIdentifier:@"zh-Hans-US"]);
//  zh-Hans-US components: {
//    kCFLocaleCountryCodeKey = US;
//    kCFLocaleLanguageCodeKey = zh;
//    kCFLocaleScriptCodeKey = Hans;
//  }
```

But that is, probably, a crutch again. The point is that it is conceptually better to rely on `language ID`s than just language designators, API was built with that in mind. Unless you have a great reason or specific task, you really should stick with NSBundle API and let it decide which localization is the best fit. 

This changes were made to enhance language fallback logic. You can read more on that here: [Language Identifiers in iOS 9](https://developer.apple.com/library/ios/technotes/tn2418/_index.html#//apple_ref/doc/uid/DTS40016588-CH1-LANGUAGE_IDENTIFIERS_IN_IOS_9).